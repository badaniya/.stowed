#!/usr/bin/env python3
"""Host side: deliver pass-backed Git credentials through Incus stdin, never files."""
import argparse
import base64
import fcntl
import json
import os
import re
import resource
import stat
import subprocess
import sys
from contextlib import contextmanager
from pathlib import Path


def run(command, data=None, env=None):
    result = subprocess.run(command, input=data, env=env, capture_output=True, timeout=30)
    if result.returncode:
        raise ValueError('credential operation failed; values suppressed')
    return result.stdout


def remove_legacy(incus, instance, name):
    result = subprocess.run([*incus, 'config', 'unset', instance, 'systemd.credential.'+name], capture_output=True, timeout=30)
    if result.returncode and b'not currently set' not in result.stderr:
        raise ValueError('could not remove legacy persistent credential')


@contextmanager
def delivery_lock(project, instance):
    """Serialize code installation, broker updates and Git config for one guest."""
    root = Path.home()/'.local/state/labctl/credential-delivery-locks'
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = root.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError('unsafe credential delivery lock directory')
    fd = os.open(root/(project+'.'+instance+'.lock'), os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'rb') as lock:
        info = os.fstat(lock.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise ValueError('unsafe credential delivery lock')
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=('sync', 'blob', 'unset'))
    parser.add_argument('--instance', required=True)
    parser.add_argument('--project', required=True)
    parser.add_argument('--host', required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--user', required=True)
    parser.add_argument('--format', choices=('environment', 'loggo-template'))
    parser.add_argument('--source')
    parser.add_argument('--pass-reference')
    args = parser.parse_args()
    for value in (args.instance, args.project, args.name, args.user):
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.#-]{0,63}', value):
            raise ValueError('invalid credential target')
    if not re.fullmatch(r'[a-z0-9][a-z0-9.-]*', args.host):
        raise ValueError('invalid credential host')
    with delivery_lock(args.project, args.instance):
        return deliver(args)


def deliver(args):
    incus = ['incus', '--force-local', '--project', args.project]
    remote = [*incus, 'exec', args.instance, '--', '/usr/bin/python3', '-I', '/usr/local/libexec/labctl-memory-git']
    broker = Path(__file__).with_name('credential-broker.py').read_bytes()
    install = 'install -d -m 0755 /usr/local/libexec; cat > /usr/local/libexec/labctl-memory-git; chmod 0755 /usr/local/libexec/labctl-memory-git'
    if args.mode == 'unset':
        run([*incus, 'exec', args.instance, '--', 'sh', '-c', install], broker)
        run([*remote, 'unset', '--user', args.user, '--name', args.name])
        remove_legacy(incus, args.instance, args.name)
        print('Memory Git credential unset; no credential values displayed')
        return
    if args.mode == 'blob':
        if args.format not in ('environment', 'loggo-template'):
            raise ValueError('memory input format required')
        if args.pass_reference:
            reference = args.pass_reference
            if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9/_.-]*', reference) or '..' in reference:
                raise ValueError('invalid pass input reference')
            automatic = Path.home()/'.local/bin/pass-auto-unlock'
            if automatic.is_file():
                run([str(automatic)])
            env = os.environ.copy()
            env['PASSWORD_STORE_DIR'] = str(Path.home()/'.password-store')
            env['PASSWORD_STORE_GPG_OPTS'] = ' '.join(('--batch', '--pinentry-mode', 'error'))
            data = run(['/usr/bin/pass', 'show', reference], env=env)
        elif args.source == '-':
            data = sys.stdin.buffer.read(1024 * 1024 + 1)
        elif args.source:
            with Path(args.source).open('rb') as stream:
                info = os.fstat(stream.fileno())
                if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
                    raise ValueError('unsafe memory input source')
                data = stream.read(1024 * 1024 + 1)
        else:
            raise ValueError('memory input source required')
        if len(data) > 1024 * 1024:
            raise ValueError('memory input too large')
        run([*incus, 'exec', args.instance, '--', 'sh', '-c', install], broker)
        payload = json.dumps({'kind': 'blob', 'format': args.format, 'data': base64.b64encode(data).decode()}).encode()
        run([*remote, 'inject', '--user', args.user, '--name', args.name], payload)
        run([*remote, 'configure-blob', '--user', args.user, '--name', args.name, '--format', args.format])
        remove_legacy(incus, args.instance, args.name)
        print('Private input synchronized to sandbox memory; no values displayed')
        return
    config = Path.home()/'.private_gh_accounts.json'
    with config.open() as stream:
        info = os.fstat(stream.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise ValueError('unsafe account-reference configuration')
        try:
            accounts = json.load(stream)
        except (ValueError, UnicodeError) as error:
            raise ValueError('invalid account-reference configuration') from error
    account = next((name for name in ('work', 'enterprise') if accounts.get(name, {}).get('host') == args.host), None)
    if account is None:
        raise ValueError('no approved pass-backed work/enterprise account for host')
    reference = accounts[account].get('secret')
    if not isinstance(reference, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9/_.-]*', reference) or '..' in reference:
        raise ValueError('invalid pass credential reference')
    automatic = Path.home()/'.local/bin/pass-auto-unlock'
    if automatic.is_file():
        run([str(automatic)])
    env = os.environ.copy()
    env['PASSWORD_STORE_DIR'] = str(Path.home()/'.password-store')
    # These are noninteractive GPG option flags, not a password or credential.
    env['PASSWORD_STORE_GPG_OPTS'] = ' '.join(('--batch', '--pinentry-mode', 'error'))
    token = run(['/usr/bin/pass', 'show', reference], env=env).decode().rstrip('\r\n')
    if not token or len(token) > 8192 or any(c.isspace() for c in token):
        raise ValueError('invalid pass token')
    # GitHub accepts the token as the password; no native gh login state is needed.
    fields = {'username': 'x-access-token', 'password': token}
    # This installation channel carries public code only, never credential data.
    run([*incus, 'exec', args.instance, '--', 'sh', '-c', install], broker)
    payload = json.dumps({'host': args.host, **fields}).encode()
    run([*remote, 'inject', '--user', args.user, '--name', args.name], payload)
    run([*remote, 'configure', '--user', args.user, '--name', args.name])
    # Remove legacy persistent credential data only after the new broker is ready.
    remove_legacy(incus, args.instance, args.name)
    print('Pass-backed Git credential synchronized to sandbox memory; no values displayed')


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('labctl pass credential delivery failed; credential values suppressed', file=sys.stderr)
        sys.exit(1)
