#!/usr/bin/env python3
"""Install/check review host tools. Never install in check mode or echo subprocess errors."""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def version(text):
    match = re.search(r'(?<!\d)v?(\d+\.\d+\.\d+)(?!\d)', text)
    return match.group(1) if match else None


class Tooling:
    def __init__(self, home=None, env=None, root=ROOT):
        self.home = Path(home or Path.home())
        self.root = Path(root)
        try:
            self.manifest = json.loads((self.root / 'scripts/review-tools.json').read_text())
        except (OSError, ValueError) as error:
            raise ValueError('Missing or invalid review-tools manifest') from error
        if self.manifest['schema'] != 1 or self.manifest['pi'] != 'managed-current-version':
            raise ValueError('Unsupported review-tools manifest')
        for name in ['tuicr', 'gh-dash']:
            if not re.fullmatch(r'\d+\.\d+\.\d+', self.manifest[name]['version']):
                raise ValueError('Invalid version pin')
        self.env = dict(os.environ if env is None else env)
        for key in ['GH_TOKEN', 'GITHUB_TOKEN', 'GH_ENTERPRISE_TOKEN', 'GITHUB_ENTERPRISE_TOKEN']:
            self.env.pop(key, None)
        self.env['GH_PROMPT_DISABLED'] = '1'
        self.env['GH_NO_UPDATE_NOTIFIER'] = '1'
        self.env['GH_NO_EXTENSION_UPDATE_NOTIFIER'] = '1'
        self.env['MISE_AUTO_INSTALL'] = '0'  # Broken shims must fail checks, not install tools.
        # Preserve inherited precedence. Do not source private profiles to find tools.
        paths = self.env.get('PATH', '').split(os.pathsep)
        for p in [self.home / '.local/bin', self.home / '.local/share/mise/shims',
                  self.home / '.pi/agent/bin', self.home / '.go/bin',
                  Path('/opt/nvim-linux-x86_64/bin')]:
            if str(p) not in paths:
                paths.append(str(p))
        self.env['PATH'] = os.pathsep.join(p for p in paths if p)
        self.env['HOME'] = str(self.home)
        self.launcher = Path(self.env.get('PI_LAUNCHER', self.home / '.pi/agent/bin/pi'))
        self.managed = Path(self.env.get('PI_MANAGED_INSTALL_ROOT', self.home / '.pi/agent/install'))

    def probe(self, command):
        try:
            r = subprocess.run(command, env=self.env, capture_output=True, text=True, timeout=20)
            return r.returncode == 0, r.stdout
        except (OSError, subprocess.TimeoutExpired):
            return False, ''

    def executable(self, name):
        return shutil.which(name, path=self.env['PATH'])

    def dash_binary(self):
        data = Path(self.env.get('XDG_DATA_HOME') or self.home / '.local/share')
        binary = data / 'gh/extensions/gh-dash/gh-dash'
        try:
            available = os.access(binary, os.X_OK)
        except OSError:
            available = False
        return str(binary) if available else self.executable('gh-dash')

    def check(self):
        rows = []

        def add(name, ok, detail):
            rows.append({'tool': name, 'ok': bool(ok), 'detail': detail})

        for name, arguments in self.manifest['prerequisites'].items():
            binary = self.executable(name)
            ok, output = self.probe([binary, *arguments]) if binary else (False, '')
            if name == 'node' and ok:
                found = version(output)
                minimum = self.manifest['node_minimum']
                ok = bool(found) and tuple(map(int, found.split('.'))) >= tuple(map(int, minimum.split('.')))
            detail = 'runnable' if ok else 'missing/unusable prerequisite'
            if name == 'node' and not ok:
                detail += '; Node >= ' + self.manifest['node_minimum']
            add(name, ok, detail)
        for name in self.manifest['wrappers']:
            add(name, self.executable(name), 'executable wrapper required; credentials are not probed')
        try:
            expected = (self.managed / 'current-version').read_text().strip()
        except OSError:
            expected = ''
        ok, output = self.probe([str(self.launcher), '--version'])
        add('pi', ok and bool(re.fullmatch(r'\d+\.\d+\.\d+(?:[-+][\w.-]+)?', expected))
            and output.strip() == expected, 'managed launcher must match current-version')
        binary = self.executable('tuicr')
        ok, output = self.probe([binary, '--version']) if binary else (False, '')
        pin = self.manifest['tuicr']['version']
        add('tuicr', ok and version(output) == pin, 'required version ' + pin)
        gh = self.executable('gh')
        registered, output = self.probe([gh, 'extension', 'list']) if gh else (False, '')
        pin = self.manifest['gh-dash']['version']
        registered = registered and any(self.manifest['gh-dash']['repository'] in line
                                        and version(line) == pin for line in output.splitlines())
        binary = self.dash_binary()
        ok, output = self.probe([binary, '--version']) if binary else (False, '')
        add('gh-dash', registered and ok and version(output) == pin,
            'registered extension and runnable binary required at ' + pin)
        return rows

    def execute(self, command, env=None):
        # Install logs can contain provider/config data. Never echo them on failure.
        r = subprocess.run(command, env=env or self.env, capture_output=True, text=True)
        if r.returncode:
            raise RuntimeError('Installation failed for ' + Path(command[0]).name + '; no subprocess output exposed')

    def install(self):
        rows = self.check()
        missing = {r['tool'] for r in rows if not r['ok']}
        prerequisites = missing - {'pi', 'tuicr', 'gh-dash'}
        if prerequisites:
            raise RuntimeError('Install/fix prerequisites first: ' + ', '.join(sorted(prerequisites)))
        if 'tuicr' in missing:
            mise = self.executable('mise')
            if not mise:
                raise RuntimeError('Install mise before installing tuicr')
            entry = self.manifest['tuicr']
            print('Installing tuicr ' + entry['version'], flush=True)
            self.execute([mise, 'install', entry['mise'] + '@' + entry['version']])
            self.execute([mise, 'reshim'])
        if 'pi' in missing:
            print('Installing/repairing managed Pi', flush=True)
            env = dict(self.env)
            env['PATH'] = str(self.launcher.parent) + os.pathsep + env['PATH']
            self.execute(['bash', str(self.root / 'scripts/pi-bootstrap.sh')], env)
        if 'gh-dash' in missing:
            # Public downloads use an existing scoped wrapper, never native-token fallback.
            wrapper = self.home / '.local/bin/gh-work'
            try:
                available = os.access(wrapper, os.X_OK)
            except OSError:
                available = False
            if not available:
                raise RuntimeError('Set up gh-work before installing the gh-dash extension')
            entry = self.manifest['gh-dash']
            gh = self.executable('gh')
            listed, output = self.probe([gh, 'extension', 'list'])
            if listed and entry['repository'] in output:
                data = Path(self.env.get('XDG_DATA_HOME') or self.home / '.local/share')
                extension = data / 'gh/extensions/gh-dash'
                if not extension.is_dir() or extension.is_symlink():
                    raise RuntimeError('Refusing to replace independently managed gh-dash')
                backup = self.home / '.local/state/dotfiles/review-tools' / ('gh-dash-' + str(time.time_ns()))
                backup.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
                shutil.copytree(extension, backup, symlinks=True)
                backup.chmod(0o700)
                self.execute([gh, 'extension', 'remove', 'gh-dash'])
            print('Installing gh-dash ' + entry['version'], flush=True)
            self.execute([str(wrapper), 'extension', 'install', entry['repository'], '--pin', 'v' + entry['version']])
        remaining = [r['tool'] for r in self.check() if not r['ok']]
        if remaining:
            raise RuntimeError('Installed tools still fail checks: ' + ', '.join(remaining))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--check', action='store_true')
    mode.add_argument('--install', action='store_true')
    mode.add_argument('--path', action='store_true', help='Print the dependency PATH without changing anything')
    args = parser.parse_args()
    try:
        tooling = Tooling()
        if args.path:
            print(tooling.env['PATH'])
            return 0
        if args.install:
            tooling.install()
        rows = tooling.check()
        for row in rows:
            print(('OK     ' if row['ok'] else 'MISSING') + '  ' + row['tool'] + ': ' + row['detail'])
        return int(any(not row['ok'] for row in rows))
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        print('review-tools: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
