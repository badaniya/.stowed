#!/usr/bin/env python3
"""Record trust for one canonical Claude launch directory, not permission bypass."""

import fcntl
import json
import os
import stat
import sys
import tempfile
from pathlib import Path


def trust_directory(directory: Path, config: Path) -> None:
    directory = directory.resolve(strict=True)
    if not directory.is_dir() or directory == Path(directory.anchor):
        raise ValueError("expected a workspace directory, not a filesystem root")
    config = config.expanduser().resolve()
    config.parent.mkdir(parents=True, exist_ok=True)
    lock_fd = os.open(
        str(config) + ".workspace-trust.lock", os.O_CREAT | os.O_RDWR, 0o600
    )
    with os.fdopen(lock_fd, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        # Serialize our launchers and retry if another Claude process updates
        # its config while we prepare the atomic replacement.
        for _ in range(5):
            previous = config.stat() if config.exists() else None
            try:
                data = json.loads(config.read_text()) if previous else {}
            except (OSError, json.JSONDecodeError) as error:
                raise ValueError(
                    "could not read valid Claude config; existing file left unchanged"
                ) from error
            if not isinstance(data, dict):
                raise TypeError("Claude config must be a JSON object")
            projects = data.setdefault("projects", {})
            if not isinstance(projects, dict):
                raise TypeError("Claude projects config must be a JSON object")
            project = projects.setdefault(str(directory), {})
            if not isinstance(project, dict):
                raise TypeError("Claude workspace config must be a JSON object")
            if project.get("hasTrustDialogAccepted") is True:
                return
            project["hasTrustDialogAccepted"] = True
            fd, name = tempfile.mkstemp(
                prefix=".claude-workspace-trust-", dir=config.parent
            )
            temporary = Path(name)
            try:
                with os.fdopen(fd, "w") as output:
                    json.dump(data, output, indent=2)
                    output.write("\n")
                    output.flush()
                    os.fsync(output.fileno())
                temporary.chmod(stat.S_IMODE(previous.st_mode) if previous else 0o600)
                current = config.stat() if config.exists() else None
                before = (
                    (previous.st_ino, previous.st_mtime_ns, previous.st_size)
                    if previous
                    else None
                )
                after = (
                    (current.st_ino, current.st_mtime_ns, current.st_size)
                    if current
                    else None
                )
                if after != before:
                    continue
                os.replace(temporary, config)
                return
            finally:
                temporary.unlink(missing_ok=True)
    raise RuntimeError("Claude config kept changing; retry the workspace launch")


def main() -> None:
    if len(sys.argv) != 2:
        raise ValueError("Usage: claude-workspace-trust.py <workspace-directory>")
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR")
    config = (
        Path(config_dir).expanduser() / ".claude.json"
        if config_dir
        else Path.home() / ".claude.json"
    )
    trust_directory(Path(sys.argv[1]), config)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, TypeError, RuntimeError) as error:
        print(
            f"Error: could not record Claude workspace trust: {error}", file=sys.stderr
        )
        sys.exit(1)
