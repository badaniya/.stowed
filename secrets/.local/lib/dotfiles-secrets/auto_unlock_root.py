#!/usr/bin/python3 -I
"""Root-owned, argument-restricted GPG cache loader. Never output an unlock secret."""
import json
import os
import pwd
import re
import resource
import stat
import subprocess
import sys
from pathlib import Path

STORE = Path('/var/lib/dotfiles-secrets-auto-unlock')
NAME = 'dotfiles-gpg-unlock'
PRESET = '/usr/lib/gnupg/gpg-preset-passphrase'


def validate_payload(data, uid):
    if not isinstance(data, dict) or data.get('uid') != uid:
        raise ValueError('credential identity mismatch')
    phrase, grips = data.get('passphrase'), data.get('keygrips')
    if not isinstance(phrase, str) or not phrase or len(phrase) > 8192 or '\n' in phrase or '\r' in phrase:
        raise ValueError('invalid passphrase payload')
    if not isinstance(grips, list) or not 1 <= len(grips) <= 16:
        raise ValueError('invalid keygrip list')
    if any(not isinstance(g, str) or not re.fullmatch(r'[A-Fa-f0-9]{40}', g) for g in grips):
        raise ValueError('invalid keygrip')
    return phrase.encode() + b'\n', grips


def child_as_user(user, args, data=None):
    def drop():
        os.initgroups(user.pw_name, user.pw_gid)
        os.setgid(user.pw_gid)
        os.setuid(user.pw_uid)
    env = {'HOME': user.pw_dir, 'GNUPGHOME': str(Path(user.pw_dir)/'.gnupg'),
           'XDG_RUNTIME_DIR': '/run/user/' + str(user.pw_uid), 'PATH': '/usr/bin:/bin', 'LC_ALL': 'C'}
    result = subprocess.run(args, input=data, env=env, preexec_fn=drop, capture_output=True, timeout=10)
    if result.returncode:
        raise ValueError('GPG agent cache setup failed')


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    os.umask(0o077)
    if os.geteuid() != 0:
        raise ValueError('root helper requires privileged invocation')
    mode = sys.argv[1:]
    if mode not in ([], ['--enroll'], ['--status'], ['--pam']):
        raise ValueError('unsupported arguments')
    if mode == ['--pam']:
        if os.environ.get('PAM_TYPE') != 'open_session':
            return 0
        user = pwd.getpwnam(os.environ.get('PAM_USER', ''))
        uid = user.pw_uid
        if uid == 0:
            return 0
    else:
        if not os.environ.get('SUDO_UID', '').isdigit():
            raise ValueError('invoke through the authorized sudo rule')
        uid = int(os.environ['SUDO_UID'])
        if uid == 0:
            raise ValueError('root enrollment is not supported')
        user = pwd.getpwuid(uid)
    if STORE.is_symlink():
        raise ValueError('unsafe credential directory')
    STORE.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = STORE.stat()
    if info.st_uid != 0 or info.st_mode & 0o077:
        raise ValueError('credential directory must be root-owned mode 0700')
    target = STORE / (str(uid) + '.cred')
    if mode == ['--status']:
        print(json.dumps({'enrolled': target.is_file() and not target.is_symlink()}))
        return 0
    if mode == ['--enroll']:
        try:
            data = json.loads(sys.stdin.buffer.read(65537))
        except (ValueError, UnicodeError) as error:
            raise ValueError('invalid enrollment payload') from error
        validate_payload(data, uid)
        if target.exists() or target.is_symlink():
            raise ValueError('already enrolled; explicit administrator removal required to replace')
        tpm = any(Path(p).exists() for p in ('/dev/tpmrm0', '/dev/tpm0'))
        backend = 'host+tpm2' if tpm else 'host'
        subprocess.run(['/usr/bin/systemd-creds', 'setup'], check=True, capture_output=True)
        result = subprocess.run(['/usr/bin/systemd-creds', 'encrypt', '--name='+NAME,
                                 '--with-key='+backend, '-', '-'],
                                input=json.dumps(data).encode(), capture_output=True)
        if result.returncode or not result.stdout:
            raise ValueError('machine-bound encryption failed')
        fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o400)
        with os.fdopen(fd, 'wb') as stream:
            stream.write(result.stdout)
            stream.flush()
            os.fsync(stream.fileno())
    else:
        if not target.exists():
            return 0 if mode == ['--pam'] else 3
        info = target.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o077:
            raise ValueError('unsafe encrypted credential')
        result = subprocess.run(['/usr/bin/systemd-creds', 'decrypt', '--name='+NAME, str(target), '-'], capture_output=True, timeout=10)
        if result.returncode:
            raise ValueError('machine-bound credential decryption failed')
        try:
            data = json.loads(result.stdout)
        except (ValueError, UnicodeError) as error:
            raise ValueError('invalid encrypted credential payload') from error
    phrase, grips = validate_payload(data, uid)
    child_as_user(user, ['/usr/bin/gpgconf', '--launch', 'gpg-agent'])
    for grip in grips:
        child_as_user(user, [PRESET, '--preset', grip], phrase)
    if mode == ['--enroll']:
        print('Enrollment complete; unlock secret encrypted locally, never printed.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception:
        print('pass-auto-unlock: operation failed; verify enrollment, machine key and GPG agent configuration', file=sys.stderr)
        sys.exit(1)
