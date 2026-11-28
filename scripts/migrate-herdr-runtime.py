#!/usr/bin/env python3
"""Offline, backup-first migration from a folded Stow directory to runtime storage."""
import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    target = config / 'herdr'
    source = ROOT / 'herdr/.config/herdr'
    if not target.is_symlink():
        print('Herdr already has a real runtime directory; no migration needed.')
        return 0
    if target.resolve() != source.resolve():
        parser.error('Herdr link is not owned by this checkout; refusing migration')
    for path in [target / 'herdr.sock', target / 'herdr-client.sock', Path(os.environ.get('HERDR_SOCKET_PATH', str(target / 'herdr.sock')))]:
        with socket.socket(socket.AF_UNIX) as connection:
            connection.settimeout(1)
            try:
                connection.connect(str(path))
            except FileNotFoundError:
                continue
            except ConnectionRefusedError:
                continue
            except OSError:
                parser.error('cannot establish server inactivity; refusing migration')
            parser.error('Herdr is running. Quit it yourself before offline migration; no server was stopped.')
    if not args.apply:
        print('Would copy runtime state to a real ~/.config/herdr directory, preserve private links, and relink tracked configuration. Run with --apply when Herdr is stopped.')
        return 0
    # The original checkout and top-level link are retained, even on success.
    staging = Path(tempfile.mkdtemp(prefix='herdr-migrate-', dir=config))
    backup = target.with_name(staging.name + '-original-link')
    try:
        runtime = staging / 'runtime'
        shutil.copytree(source, runtime, symlinks=True, ignore=shutil.ignore_patterns('*.sock', '*.sock.lock'))
        registry = runtime / 'plugins.json'
        if registry.exists():
            data = registry.read_text().replace(str(source.resolve()) + '/', str(target) + '/')
            json.loads(data)
            registry.write_text(data)
        files = subprocess.check_output(['git', '-C', str(ROOT), 'ls-files', '-z', 'herdr/.config/herdr']).decode().split('\0')
        for relative in filter(None, files):
            original = ROOT / relative
            destination = runtime / original.relative_to(source)
            if original.name == '.gitignore':
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            if destination.exists() or destination.is_symlink():
                destination.unlink()
            destination.symlink_to(original)
        target.rename(backup)
        try:
            runtime.rename(target)
        except OSError:
            backup.rename(target)
            raise
        print(f'Migrated Herdr runtime. Original link retained at {backup}. Checkout runtime data retained for recovery; do not delete until verified.')
    finally:
        shutil.rmtree(staging)
    return 0


if __name__ == '__main__':
    sys.exit(main())
