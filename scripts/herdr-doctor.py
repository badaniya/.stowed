#!/usr/bin/env python3
"""Read-only checks for portable Herdr deployment; never prints secret values."""
import argparse
import json
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=['public', 'work'], default='public')
    args = parser.parse_args()
    problems = []
    config = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    for name, source in [('herdr', 'herdr/.config/herdr'), ('herdr-spreader', 'herdr-spreader/.config/herdr-spreader'), ('herdr-action-errors', 'herdr/.config/herdr-action-errors')]:
        target = config / name
        if not target.exists():
            problems.append(f'{target}: missing or broken deployment')
        elif target.is_symlink() and target.resolve() != (ROOT / source).resolve():
            problems.append(f'{target}: points to the wrong package')
    for tool in ['herdr', 'python3', 'git', 'jq', 'stow', 'herdr-spreader']:
        if not shutil.which(tool):
            problems.append(f'{tool}: missing from PATH')
    try:
        entries = json.loads((config / 'herdr/plugins.json').read_text())
        for line in (ROOT / 'herdr/.config/herdr/plugins.txt').read_text().splitlines():
            fields = line.split()
            if not fields or fields[0].startswith('#'):
                continue
            if fields[0] == 'github':
                expected = fields[1]
                matches = [e for e in entries if e.get('source', {}).get('owner', '') + '/' + e.get('source', {}).get('repo', '') == expected]
                if not matches or not matches[0].get('enabled') or matches[0].get('source', {}).get('resolved_commit') != fields[2]:
                    problems.append(f'{expected}: missing, disabled or incorrect pinned commit')
            elif fields[0] == 'local':
                expected = (ROOT / fields[1]).resolve()
                if not any(e.get('enabled') and Path(e.get('plugin_root', '')).resolve() == expected for e in entries):
                    problems.append(f'{fields[1]}: local plugin not registered/enabled')
        for entry in entries:
            if not Path(entry['manifest_path']).is_file():
                problems.append(f'{entry["plugin_id"]}: missing manifest')
            if entry['plugin_id'] == 'herdr-spreader':
                binary = Path(entry['plugin_root']) / 'target/release/herdr-spreader'
                if not os.access(binary, os.X_OK):
                    problems.append('Spreader plugin binary: missing or not executable')
    except (OSError, ValueError, TypeError, KeyError):
        problems.append('Herdr registry missing or malformed; install declared plugins')
    for package in ['herdr/.config/herdr/plugins/config', 'herdr-spreader/.config/herdr-spreader']:
        for base, dirs, files in os.walk(ROOT / package):
            for name in dirs + files:
                path = Path(base) / name
                if path.is_symlink() and not path.exists():
                    problems.append(f'broken link: {path.relative_to(ROOT)}')
    if args.profile == 'work':
        for name in ['.private_herdr_spreader', '.private_herdr_quick_actions', '.private_work.env']:
            path = Path.home() / name
            if not path.exists():
                problems.append(f'{name}: required by work profile')
            elif path.stat().st_mode & 0o077:
                problems.append(f'{name}: private data should not be group/world accessible')
    for problem in problems:
        print(f'ERROR: {problem}', file=sys.stderr)
    print(f'Herdr doctor ({args.profile}): {len(problems)} problem(s)')
    return 1 if problems else 0


if __name__ == '__main__':
    sys.exit(main())
