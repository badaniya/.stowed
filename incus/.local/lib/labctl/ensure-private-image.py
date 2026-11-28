#!/usr/bin/env python3
"""Ensure a local golden image from owner-only, checksum-verified private assets."""

import argparse
import fcntl
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote


def secure_directory(path):
    info = path.lstat()
    if (
        not stat.S_ISDIR(info.st_mode)
        or info.st_uid != os.getuid()
        or info.st_mode & 0o077
    ):
        raise ValueError("private image directory must be owner-only")


def secure_file(path):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    stream = os.fdopen(fd, "rb")
    info = os.fstat(fd)
    if (
        not stat.S_ISREG(info.st_mode)
        or info.st_uid != os.getuid()
        or info.st_mode & 0o077
    ):
        stream.close()
        raise ValueError("private image file must be owner-only and regular")
    return stream


def parse_object(content):
    try:
        value = json.loads(content)
    except (ValueError, UnicodeError, TypeError) as error:
        raise ValueError("invalid private image JSON") from error
    if not isinstance(value, dict):
        raise ValueError("private image JSON must be an object")
    return value


def run(command):
    return subprocess.run(command, capture_output=True, timeout=300)


def ensure_image(image, project, home=None, runner=run, dry_run=False):
    if not image.startswith("local:golden:"):
        return  # Honor explicit non-golden image selections; never invent a fallback.
    alias = image.removeprefix("local:")
    if not re.fullmatch(
        r"golden:[A-Za-z0-9][A-Za-z0-9._-]*", alias
    ) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", project):
        raise ValueError("invalid local image target")
    home = Path.home() if home is None else Path(home)
    root = home / ".private-sandbox-images"
    secure_directory(root)
    with secure_file(root / "manifest.json") as stream:
        manifest = parse_object(stream.read())
    if (
        not isinstance(manifest, dict)
        or manifest.get("schema_version") != 1
        or not isinstance(manifest.get("images"), list)
    ):
        raise ValueError("invalid private image manifest")
    records = [
        r for r in manifest["images"] if isinstance(r, dict) and r.get("alias") == alias
    ]
    if len(records) != 1:
        raise ValueError("configured golden alias must have one manifest record")
    record = records[0]
    fingerprint = record.get("fingerprint")
    name = record.get("archive")
    if (
        not isinstance(fingerprint, str)
        or not re.fullmatch(r"[a-f0-9]{64}", fingerprint)
        or record.get("sha256") != fingerprint
    ):
        raise ValueError("invalid unified image fingerprint/checksum")
    if (
        not isinstance(name, str)
        or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*\.tar\.gz", name)
        or ".." in name
    ):
        raise ValueError("unsafe private archive filename")
    if (
        record.get("type") != "container"
        or record.get("architecture") != "x86_64"
        or not isinstance(record.get("bytes"), int)
        or record["bytes"] <= 0
    ):
        raise ValueError("unsupported private image metadata")
    prefix = ["incus", "--force-local"]
    project_check = runner(
        [*prefix, "query", "/1.0/projects/" + quote(project, safe="")]
    )
    if project_check.returncode:
        raise ValueError("Incus project unavailable; refusing image fallback")
    query = [
        *prefix,
        "query",
        "/1.0/images/aliases/"
        + quote(alias, safe="")
        + "?project="
        + quote(project, safe=""),
    ]

    def check_or_import():
        result = runner(query)
        if result.returncode == 0:
            if parse_object(result.stdout).get("target") != fingerprint:
                raise ValueError(
                    "installed alias differs from private manifest; refusing replacement"
                )
            print("Private golden image already available; fingerprint verified")
            return
        if b"not found" not in result.stderr.lower():
            raise ValueError("Incus alias lookup failed; refusing image fallback")
        archive = root / name
        with secure_file(archive) as stream:
            info = os.fstat(stream.fileno())
            if info.st_size != record["bytes"]:
                raise ValueError("private image archive size mismatch")
            digest = hashlib.sha256()
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
            current = archive.lstat()
            if digest.hexdigest() != fingerprint or (
                current.st_ino,
                current.st_size,
                current.st_mtime_ns,
            ) != (info.st_ino, info.st_size, info.st_mtime_ns):
                raise ValueError("private image archive checksum/state mismatch")
            if dry_run:
                print("Dry run: verified private golden archive would be imported")
                return
            imported = runner(
                [
                    *prefix,
                    "--project",
                    project,
                    "image",
                    "import",
                    str(archive),
                    "--alias",
                    alias,
                ]
            )
            if imported.returncode:
                raise ValueError("private golden image import failed")
        installed = runner(query)
        if (
            installed.returncode
            or parse_object(installed.stdout).get("target") != fingerprint
        ):
            raise ValueError("imported golden image fingerprint mismatch")
        print("Private golden image imported; fingerprint verified")

    if dry_run:
        return check_or_import()
    locks = home / ".local/state/labctl/private-image-locks"
    locks.mkdir(mode=0o700, parents=True, exist_ok=True)
    secure_directory(locks)
    fd = os.open(
        locks / (project + "." + alias.replace(":", "-") + ".lock"),
        os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW,
        0o600,
    )
    with os.fdopen(fd, "rb") as lock:
        info = os.fstat(lock.fileno())
        if (
            not stat.S_ISREG(info.st_mode)
            or info.st_uid != os.getuid()
            or info.st_mode & 0o077
        ):
            raise ValueError("unsafe image import lock")
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        check_or_import()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    try:
        ensure_image(args.image, args.project, dry_run=args.dry_run)
    except (ValueError, OSError, TypeError, subprocess.SubprocessError):
        print(
            "labctl: private golden image unavailable or invalid; check manifest, permissions, checksum and Incus project",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
