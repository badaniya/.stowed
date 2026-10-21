import os
import subprocess
import tempfile

import pytest

from conftest import (
    GIT_ENV, STUB_VULN, VULN_PY, git, make_repo, metrics_of, run_hook,
    stop_payload, ups_payload,
)

import gitutil


def _add_nested_repo(parent, rel, marker):
    """A directory with its own `.git` whose config names a filter command,
    the way an unpacked archive or a vendored checkout can. The command leaves
    a line in `marker` each time git runs it."""
    nested = make_repo(parent / rel, {
        "lib.py": "print('one')\n",
        ".gitattributes": "* filter=probe\n",
    })
    git(nested, "config", "filter.probe.clean",
        f"sh -c 'echo ran >> \"{marker.as_posix()}\"; cat'")
    # Same size, so git has to read the file to tell whether it changed.
    (nested / "lib.py").write_text("print('two')\n")
    old = os.stat(nested / ".git" / "index").st_mtime - 3600
    os.utime(nested / ".git" / "index", (old, old))
    return nested


@pytest.fixture
def outer(tmp_path):
    return make_repo(tmp_path / "outer", {"app.py": "print('hi')\n"})


@pytest.fixture
def marker(tmp_path):
    return tmp_path / "filter-ran"


def _turn(repo, hook_env, stub_api, during):
    stub_api.vulns = [STUB_VULN]
    assert run_hook(ups_payload(repo), hook_env)[0] == 0
    during()
    return run_hook(stop_payload(repo), hook_env)


def test_untracked_nested_repo_filter_not_run(outer, marker, hook_env, stub_api):
    def during():
        _add_nested_repo(outer, "vendor/pkg", marker)
        (outer / "app.py").write_text(VULN_PY)

    rc, out, err = _turn(outer, hook_env, stub_api, during)

    assert not marker.exists(), marker.read_text()
    # The turn's own edit is still reviewed.
    assert stub_api.calls, (rc, out, err)
    assert "app.py" in out + err


def test_untracked_nested_repo_alone_is_not_reviewed(outer, marker, hook_env, stub_api):
    rc, out, err = _turn(
        outer, hook_env, stub_api,
        lambda: _add_nested_repo(outer, "vendor/pkg", marker))

    assert not marker.exists(), marker.read_text()
    assert not stub_api.calls
    assert (metrics_of(out) or {}).get("skipped") is True


@pytest.fixture
def git_env(tmp_path, monkeypatch):
    """For calling gitutil in this process: a temp dir of our own, and the
    environment restored afterwards."""
    d = tmp_path / "tmproot"
    d.mkdir()
    monkeypatch.setattr(tempfile, "tempdir", str(d))
    saved = dict(os.environ)
    os.environ.update(GIT_ENV)
    yield
    os.environ.clear()
    os.environ.update(saved)


def _record_nested_repo(outer, marker, gitmodules=None):
    nested = _add_nested_repo(outer, "vendor/pkg", marker)
    if gitmodules:
        (outer / ".gitmodules").write_text(gitmodules)
    git(outer, "add", "-A")
    git(outer, "commit", "-q", "-m", "add vendor/pkg")
    if marker.exists():
        marker.unlink()
    return nested


def test_untracked_nested_repo_is_not_a_changed_file(outer, marker, git_env):
    _add_nested_repo(outer, "vendor/pkg", marker)
    (outer / "new.py").write_text("x = 1\n")

    tracked, untracked = gitutil._git_status_porcelain(str(outer))

    assert (tracked, untracked) == (set(), {"new.py"})


def test_intent_to_add_skips_nested_repos(outer, marker, git_env):
    _add_nested_repo(outer, "vendor/pkg", marker)
    (outer / "new.py").write_text("x = 1\n")

    with gitutil._temp_index(str(outer), ["new.py", "vendor/pkg/"]) as env:
        assert env is not None
        listed = subprocess.run(
            ["git", "ls-files", "-s"], cwd=outer, capture_output=True,
            text=True, env=env,
        ).stdout

    assert "new.py" in listed
    assert "160000" not in listed
    assert not marker.exists()


# A repository can ask for one submodule to be checked whatever the default.
GITMODULES_IGNORE_NONE = (
    '[submodule "pkg"]\n\tpath = vendor/pkg\n\turl = ./vendor/pkg\n\tignore = none\n'
)


@pytest.mark.parametrize("gitmodules", [None, GITMODULES_IGNORE_NONE])
def test_status_and_diff_leave_out_recorded_nested_repo(outer, marker, git_env, gitmodules):
    nested = _record_nested_repo(outer, marker, gitmodules)
    (nested / "lib.py").write_text("print('abc')\n")
    (outer / "app.py").write_text(VULN_PY)

    tracked, untracked = gitutil._git_status_porcelain(str(outer))
    diff = gitutil.get_git_diff(str(outer), "HEAD", untracked_paths=[])
    names = gitutil._git_name_only(str(outer), "HEAD")

    assert tracked == {"app.py"}
    assert names == {"app.py"}
    assert "app.py" in diff and "vendor/pkg" not in diff
    assert not marker.exists()


def test_commit_range_diff_does_not_enter_nested_repo(outer, marker, git_env, tmp_path):
    nested = _record_nested_repo(outer, marker, GITMODULES_IGNORE_NONE)
    ext_marker = tmp_path / "ext-diff-ran"
    git(nested, "config", "diff.external",
        f"sh -c 'echo ran >> \"{ext_marker.as_posix()}\"'")
    base = git(outer, "rev-parse", "HEAD").strip()
    git(nested, "commit", "-q", "-am", "two")
    git(outer, "commit", "-q", "-am", "move vendor/pkg")
    for m in (marker, ext_marker):
        if m.exists():
            m.unlink()
    # The user's own setting asks for a submodule's changes inline.
    os.environ.update({"GIT_CONFIG_COUNT": "1", "GIT_CONFIG_KEY_0": "diff.submodule",
                       "GIT_CONFIG_VALUE_0": "diff"})

    out = gitutil._git_diff_range(str(outer), base, "HEAD")

    assert not ext_marker.exists() and not marker.exists()
    assert "lib.py" not in (out or "")
