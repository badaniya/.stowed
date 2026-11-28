#!/usr/bin/python3 -I
"""Guest Git credential broker. Secret values exist only in memory and IPC."""
import argparse
import base64
import fcntl
import json
import os
import pwd
import re
import resource
import select
import shlex
import socket
import stat
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path('/run/labctl-memory')
INSTALLED = '/usr/local/libexec/labctl-memory-git'
INPUTS = Path('/etc/labctl-memory-inputs')
MAX_MESSAGE = 2 * 1024 * 1024


def parse_environment(text):
    values = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        parts = shlex.split(line)
        if len(parts) != 2 or parts[0] != 'export' or '=' not in parts[1]:
            raise ValueError('environment must contain literal export entries only')
        name, value = parts[1].split('=', 1)
        if not re.fullmatch(r'[A-Za-z_][A-Za-z0-9_]*', name) or name in values or '\0' in value:
            raise ValueError('invalid environment entry')
        values[name] = value
    return values


def validate_payload(value):
    if not isinstance(value, dict) or value.get('kind', 'git') == 'git':
        return validate_credential(value)
    if value.get('kind') != 'blob' or value.get('format') not in ('environment', 'loggo-template'):
        raise ValueError('invalid memory input kind')
    data = base64.b64decode(value.get('data', ''), validate=True)
    if len(data) > 1024 * 1024:
        raise ValueError('memory input exceeds size limit')
    if value['format'] == 'environment':
        parse_environment(data.decode())
    return {'kind': 'blob', 'format': value['format'], 'data': base64.b64encode(data).decode()}


def sealed_template(data):
    fd = os.memfd_create('labctl-template', os.MFD_ALLOW_SEALING)
    try:
        view = memoryview(data)
        while view:
            view = view[os.write(fd, view):]
        os.lseek(fd, 0, os.SEEK_SET)
        fcntl.fcntl(fd, fcntl.F_ADD_SEALS, fcntl.F_SEAL_WRITE | fcntl.F_SEAL_GROW | fcntl.F_SEAL_SHRINK | fcntl.F_SEAL_SEAL)
        os.set_inheritable(fd, True)
        return fd
    except Exception:
        os.close(fd)
        raise


def validate_credential(value):
    if not isinstance(value, dict):
        raise ValueError('invalid credential')
    host, user, token = value.get('host'), value.get('username'), value.get('password')
    if not isinstance(host, str) or not re.fullmatch(r'[a-z0-9][a-z0-9.-]*', host):
        raise ValueError('invalid credential host')
    if not isinstance(user, str) or not user or any(c.isspace() for c in user) or '=' in user:
        raise ValueError('invalid credential username')
    if not isinstance(token, str) or not token or len(token) > 8192 or any(c.isspace() for c in token):
        raise ValueError('invalid credential token')
    return {'host': host, 'username': user, 'password': token}


def credential_response(value, request):
    if not value or value.get('kind', 'git') != 'git' or request.get('protocol') != 'https' or request.get('host') != value['host']:
        return {}
    return {'username': value['username'], 'password': value['password']}


def socket_path(uid, name):
    if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,63}', name):
        raise ValueError('invalid credential name')
    return ROOT / str(uid) / (name + '.sock')


def exchange(path, request):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect(str(path))
        client.sendall(json.dumps(request).encode() + b'\n')
        with client.makefile('rb') as stream:
            line = stream.readline(MAX_MESSAGE + 1)
            if len(line) > MAX_MESSAGE:
                raise ValueError('oversized broker response')
            try:
                return json.loads(line)
            except (ValueError, UnicodeError) as error:
                raise ValueError('invalid broker response') from error


def serve(listener, path, uid, value):
    try:
        running = True
        while running:
            connection, _ = listener.accept()
            with connection:
                connection.settimeout(5)
                peer = struct.unpack('3i', connection.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))[1]
                response = {}
                try:
                    if peer not in (0, uid):
                        raise ValueError('unauthorized peer')
                    with connection.makefile('rb') as stream:
                        line = stream.readline(MAX_MESSAGE + 1)
                    if len(line) > MAX_MESSAGE:
                        raise ValueError('oversized broker request')
                    request = json.loads(line)
                    if not isinstance(request, dict):
                        raise ValueError('invalid broker request')
                    if request.get('op') == 'get':
                        response = credential_response(value, request)
                    elif request.get('op') == 'blob' and value.get('kind') == 'blob':
                        response = {'format': value['format'], 'data': value['data']}
                    elif request.get('op') == 'set' and peer == 0:
                        value = validate_payload(request['credential'])
                        response = {'ok': True}
                    elif request.get('op') == 'unset' and peer == 0:
                        value.clear()
                        response = {'ok': True}
                        running = False
                    else:
                        raise ValueError('unsupported broker operation')
                except (ValueError, KeyError, UnicodeError, OSError, TypeError):
                    response = {'error': 'credential request rejected'}
                try:
                    connection.sendall(json.dumps(response).encode() + b'\n')
                except OSError:
                    # A cancelled Git client must not kill the credential broker.
                    continue
    finally:
        listener.close()
        path.unlink(missing_ok=True)


def inject(user, name, value):
    if os.geteuid() != 0:
        raise ValueError('injection requires sandbox root')
    value = validate_payload(value)
    path = socket_path(user.pw_uid, name)
    if ROOT.is_symlink():
        raise ValueError('unsafe broker directory')
    ROOT.mkdir(mode=0o755, exist_ok=True)
    info = ROOT.stat()
    if info.st_uid != 0 or info.st_mode & 0o022:
        raise ValueError('broker parent must be root-owned and not writable by other users')
    ROOT.chmod(0o755)
    if path.parent.is_symlink():
        raise ValueError('unsafe broker user directory')
    path.parent.mkdir(mode=0o700, exist_ok=True)
    os.chown(path.parent, user.pw_uid, user.pw_gid)
    path.parent.chmod(0o700)
    if path.exists() or path.is_symlink():
        info = path.lstat()
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid != user.pw_uid:
            raise ValueError('unsafe existing broker socket')
        try:
            result = exchange(path, {'op': 'set', 'credential': value})
            if result.get('ok') is True:
                return
            raise ValueError('broker rejected update')
        except (ConnectionRefusedError, FileNotFoundError):
            path.unlink(missing_ok=True)
    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    listener.bind(str(path))
    path.chmod(0o600)
    os.chown(path, user.pw_uid, user.pw_gid)
    listener.listen(8)
    read_fd, write_fd = os.pipe()
    pid = os.fork()
    if pid == 0:
        os.close(read_fd)
        try:
            os.setsid()
            os.initgroups(user.pw_name, user.pw_gid)
            os.setgid(user.pw_gid)
            os.setuid(user.pw_uid)
            for fd in (0, 1, 2):
                os.close(fd)
            fd = os.open('/dev/null', os.O_RDWR)
            os.dup2(fd, 1)
            os.dup2(fd, 2)
            os.write(write_fd, b'R')
            os.close(write_fd)
            serve(listener, path, user.pw_uid, value)
            os._exit(0)
        except Exception:
            os._exit(1)
    os.close(write_fd)
    listener.close()
    ready, _, _ = select.select([read_fd], [], [], 5)
    try:
        if not ready or os.read(read_fd, 1) != b'R':
            raise ValueError('broker did not become ready')
    finally:
        os.close(read_fd)


def configure(user, name):
    if os.geteuid() != 0:
        raise ValueError('configuration requires sandbox root')
    def drop():
        os.initgroups(user.pw_name, user.pw_gid)
        os.setgid(user.pw_gid)
        os.setuid(user.pw_uid)
    env = {'HOME': user.pw_dir, 'PATH': '/usr/bin:/bin'}
    helper = '!/usr/bin/python3 -I ' + INSTALLED + ' git --name ' + shlex.quote(name)
    for args in [('--replace-all', 'credential.helper', ''), ('--add', 'credential.helper', helper), ('credential.useHttpPath', 'true'), ('--replace-all', 'http.extraHeader', '')]:
        subprocess.run(['/usr/bin/git', 'config', '--global', *args], env=env, preexec_fn=drop, check=True, capture_output=True)
    # Command-scoped settings override host-helper references in mounted worktree configs.
    profile = Path('/etc/profile.d/labctl-memory-git.sh')
    profile.write_text('export GIT_CONFIG_COUNT=2\nexport GIT_CONFIG_KEY_0=credential.helper\nexport GIT_CONFIG_VALUE_0=\"\"\nexport GIT_CONFIG_KEY_1=credential.helper\nexport GIT_CONFIG_VALUE_1='+shlex.quote(helper)+'\nexport GIT_TERMINAL_PROMPT=0\n')
    profile.chmod(0o644)


def read_inputs(uid):
    path = INPUTS / (str(uid) + '.json')
    if not path.exists():
        return {}
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o022:
        raise ValueError('unsafe input metadata')
    try:
        return json.loads(path.read_text())
    except ValueError as error:
        raise ValueError('invalid input metadata') from error


def configure_blob(user, name, kind):
    if os.geteuid() != 0 or kind not in ('environment', 'loggo-template'):
        raise ValueError('invalid input configuration')
    socket_path(user.pw_uid, name)
    if INPUTS.is_symlink():
        raise ValueError('unsafe input metadata directory')
    INPUTS.mkdir(mode=0o755, exist_ok=True)
    INPUTS.chmod(0o755)
    metadata = read_inputs(user.pw_uid)
    metadata[kind] = name
    path = INPUTS / (str(user.pw_uid) + '.json')
    path.write_text(json.dumps(metadata))
    path.chmod(0o644)
    if kind == 'environment':
        profile = Path('/etc/profile.d/labctl-memory-environment.sh')
        profile.write_text('_labctl_trace=0\ncase $- in *x*) _labctl_trace=1; set +x ;; esac\nif _labctl_env=$(/usr/bin/python3 -I '+INSTALLED+' env-shell --name '+shlex.quote(name)+' 2>/dev/null); then\n  eval "$_labctl_env"\nfi\nunset _labctl_env\nif [ "$_labctl_trace" = 1 ]; then unset _labctl_trace; set -x; else unset _labctl_trace; fi\n')
        profile.chmod(0o644)
    wrapper = Path('/usr/local/bin/labctl-with-inputs')
    wrapper.write_text('#!/bin/sh\nexec /usr/bin/python3 -I '+INSTALLED+' exec -- "$@"\n')
    wrapper.chmod(0o755)
    # Remove only the controller's former generated plaintext copies.
    legacy = Path(user.pw_dir) / ('.config/monorepo/sandbox.env' if kind == 'environment' else '.private-monorepo-loggo.tpl')
    if legacy.is_file() or legacy.is_symlink():
        legacy.unlink()


def blob_data(name, expected):
    response = exchange(socket_path(os.getuid(), name), {'op': 'blob'})
    if response.get('format') != expected:
        raise ValueError('memory input format mismatch')
    return base64.b64decode(response['data'], validate=True)


def execution_environment():
    env = os.environ.copy()
    metadata = read_inputs(os.getuid())
    if metadata.get('environment'):
        env.update(parse_environment(blob_data(metadata['environment'], 'environment').decode()))
    if metadata.get('loggo-template'):
        fd = sealed_template(blob_data(metadata['loggo-template'], 'loggo-template'))
        env['LABCTL_LOGGO_TEMPLATE_FILE'] = '/proc/self/fd/' + str(fd)
    return env


def execute_command(command, env):
    # Keep anonymous template descriptors open in the child, without shell interpolation.
    path = env.get('LABCTL_LOGGO_TEMPLATE_FILE', '')
    descriptors = (int(path.rsplit('/', 1)[1]),) if path.startswith('/proc/self/fd/') else ()
    try:
        result = subprocess.run(command, env=env, pass_fds=descriptors, check=False)
        return result.returncode if result.returncode >= 0 else 128 - result.returncode
    finally:
        for fd in descriptors:
            os.close(fd)


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    os.umask(0o077)
    if sys.argv[1:2] == ['exec']:
        command = sys.argv[2:]
        if command[:1] == ['--']:
            command = command[1:]
        if not command:
            raise ValueError('command required')
        env = execution_environment()
        command = [env.get('LABCTL_LOGGO_TEMPLATE_FILE', '') if value == '{template}' else value for value in command]
        return execute_command(command, env)
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('inject', 'configure', 'configure-blob', 'env-shell', 'run', 'unset', 'git'))
    parser.add_argument('--user')
    parser.add_argument('--name', required=True)
    parser.add_argument('--format', choices=('environment', 'loggo-template'))
    parser.add_argument('operation', nargs='?', default='get')
    args = parser.parse_intermixed_args()
    if args.mode == 'env-shell':
        for name, value in parse_environment(blob_data(args.name, 'environment').decode()).items():
            print('export ' + name + '=' + shlex.quote(value))
        return
    if args.mode == 'run':
        return execute_command(['/bin/bash', '-l', '-s'], execution_environment())
    if args.mode == 'git':
        if args.operation != 'get':
            return
        fields = {}
        for line in sys.stdin.read(32769).splitlines():
            if '=' in line:
                key, value = line.split('=', 1)
                fields[key] = value
        response = exchange(socket_path(os.getuid(), args.name), {'op': 'get', 'protocol': fields.get('protocol'), 'host': fields.get('host')})
        for key in ('username', 'password'):
            if key in response:
                print(key + '=' + response[key])
        return
    user = pwd.getpwnam(args.user)
    if user.pw_uid == 0:
        raise ValueError('root credential consumers are not supported')
    if args.mode == 'inject':
        try:
            value = json.loads(sys.stdin.buffer.read(MAX_MESSAGE + 1))
        except (ValueError, UnicodeError) as error:
            raise ValueError('invalid credential input') from error
        inject(user, args.name, value)
    elif args.mode == 'configure':
        configure(user, args.name)
    elif args.mode == 'configure-blob':
        configure_blob(user, args.name, args.format)
    else:
        if os.geteuid() != 0:
            raise ValueError('unset requires sandbox root')
        path = socket_path(user.pw_uid, args.name)
        if path.exists() and exchange(path, {'op': 'unset'}).get('ok') is not True:
            raise ValueError('broker unset failed')
    print('Memory credential operation completed')


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        print('labctl credential broker: operation failed; credential values suppressed', file=sys.stderr)
        sys.exit(1)
