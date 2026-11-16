"""Run with: python3 -m unittest discover -s tests/zsh -v.

Uses the real stowed zshrc, vendored zsh-vi-mode and installed Starship in a PTY.
No personal startup files, history or mode-cache files are read or modified.
"""

import errno
import fcntl
import os
import pty
import re
import select
import shutil
import struct
import subprocess
import tempfile
import termios
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STARSHIP = shutil.which("starship") or ""
ZSH = shutil.which("zsh") or ""
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


class Shell:
    def __init__(self, home, directory, extra_env=None):
        self.fd, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 140, 0, 0))
        env = {
            "HOME": str(home),
            "ZDOTDIR": str(home),
            "PATH": f"{Path(STARSHIP).parent}:/usr/bin:/bin",
            "TERM": "xterm-256color",
            "LANG": "C.UTF-8",
            "PWD": str(directory),
            "STARSHIP_CONFIG": str(ROOT / "starship/.config/starship.toml"),
            "DISABLE_AUTO_UPDATE": "true",
            "ZSH_CACHE_DIR": str(home / ".cache/oh-my-zsh"),
        }
        env.update(extra_env or {})

        # Reopen the slave after setsid to acquire a controlling terminal,
        # without running Python in a potentially multithreaded preexec_fn.
        try:
            self.process = subprocess.Popen(
                [
                    ZSH,
                    "-d",
                    "-f",
                    "-c",
                    'exec < "$1" > "$1" 2>&1; exec "$2" -d -i',
                    "stowed-pty",
                    os.ttyname(slave),
                    ZSH,
                ],
                cwd=directory,
                env=env,
                stdin=slave,
                stdout=slave,
                stderr=slave,
                start_new_session=True,
            )
        except BaseException:
            os.close(self.fd)
            raise
        finally:
            os.close(slave)
        self.output = b""
        self.transcript = b""

    def send(self, keys):
        os.write(self.fd, keys.encode())

    def expect(self, text, timeout=12):
        target = text.encode()
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if target in self.output:
                before, self.output = self.output.split(target, 1)
                return before.decode(errors="replace")
            if select.select([self.fd], [], [], max(0, deadline - time.monotonic()))[0]:
                try:
                    data = os.read(self.fd, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    break
                if not data:
                    break
                self.output += data
                self.transcript += data
        raise AssertionError(
            f"Did not see {text!r}; terminal output: {self.output.decode(errors='replace')!r}"
        )

    def close(self):
        self.process.kill()
        self.process.wait(timeout=5)
        os.close(self.fd)


@unittest.skipUnless(ZSH and STARSHIP, "requires zsh and starship")
class StarshipViModeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        (self.home / ".cache/zsh").mkdir(parents=True)
        (self.home / ".oh-my-zsh").symlink_to(
            ROOT / "zsh/.oh-my-zsh", target_is_directory=True
        )
        (self.home / ".zshrc").symlink_to(ROOT / "zsh/.zshrc")
        self.directory = self.home / "prompt-fixture"
        self.directory.mkdir()
        subprocess.run(
            ["git", "init", "-q", "-b", "prompt-test-branch", str(self.directory)],
            check=True,
        )

    def shell(self, extra_env=None):
        shell = Shell(self.home, self.directory, extra_env)
        self.addCleanup(shell.close)
        return shell

    def test_original_two_line_layout_and_character_symbols(self):
        env = dict(
            os.environ,
            HOME=str(self.home),
            PWD=str(self.directory),
            STARSHIP_SHELL="zsh",
            STARSHIP_CONFIG=str(ROOT / "starship/.config/starship.toml"),
        )
        for mode, symbol in [("viins", "🤞(¬_¬٥)"), ("vicmd", "💪(•́‿•́✧)")]:
            with self.subTest(mode=mode):
                result = subprocess.run(
                    [STARSHIP, "prompt", "--terminal-width=140", f"--keymap={mode}"],
                    cwd=self.directory,
                    env=env,
                    text=True,
                    capture_output=True,
                    check=True,
                )
                self.assertEqual(result.stderr, "")
                lines = (
                    ANSI.sub("", result.stdout)
                    .replace("%{", "")
                    .replace("%}", "")
                    .strip()
                    .splitlines()
                )
                self.assertEqual(len(lines), 2, lines)
                self.assertRegex(lines[0], r"^(?:~/|…/)?prompt-fixture\s")
                self.assertRegex(
                    lines[0],
                    r"prompt-fixture\s{5,}.*prompt-test-branch.*🕐 \d{2}:\d{2}:\d{2}",
                )
                self.assertIn(symbol, lines[1])

    def test_escape_and_insert_update_original_character(self):
        shell = self.shell()
        shell.expect("🤞")
        # Repeat to catch stale closures and one-time lazy initialization bugs.
        for _ in range(2):
            shell.send("\x1b")
            shell.expect("💪")
            shell.send("i")
            shell.expect("🤞")
        self.assertNotIn(b"read-only variable", shell.transcript)
        self.assertNotIn(b"command not found", shell.transcript)

    def test_plugin_text_object_returns_to_insert_mode(self):
        shell = self.shell()
        shell.expect("🤞")
        shell.send("echo old")
        shell.send("\x1b")
        shell.expect("💪")
        shell.send("ciw")
        shell.expect("🤞")
        shell.send("new\n")
        shell.expect("new\r\n")
        shell.expect("🤞")

    def test_new_line_preserves_plugins_default_last_mode(self):
        shell = self.shell()
        shell.expect("🤞")
        shell.send("\x1b")
        shell.expect("💪")
        shell.send("\n")
        shell.expect("💪")
        shell.send("i")
        shell.expect("🤞")

    def completion_env(self, with_carapace=False):
        binary_dir = self.home / "bin"
        binary_dir.mkdir()
        command = binary_dir / "stowed-complete"
        command.write_text('#!/bin/sh\nprintf "COMPLETED:%s\\n" "$1"\n')
        command.chmod(0o755)
        if with_carapace:
            # Controlled generator boundary; the real Zsh completion widgets
            # must load this compdef and insert its result into the real buffer.
            carapace = binary_dir / "carapace"
            carapace.write_text(
                "#!/bin/sh\ncat <<'ZSH'\n"
                "_stowed_complete() { compadd completed-word; }\n"
                "compdef _stowed_complete stowed-complete\nZSH\n"
            )
            carapace.chmod(0o755)
        return {"PATH": f"{binary_dir}:{Path(STARSHIP).parent}:/usr/bin:/bin"}

    def test_plugin_completion_works_with_cold_and_warm_caches(self):
        env = self.completion_env()
        custom = self.home / "custom"
        plugin = custom / "plugins/git"
        plugin.mkdir(parents=True)
        (plugin / "git.plugin.zsh").touch()
        (plugin / "_stowed_complete").write_text(
            "#compdef stowed-complete\ncompadd completed-word\n"
        )
        for name in ["zsh-autosuggestions", "zsh-syntax-highlighting", "zsh-vi-mode"]:
            (custom / "plugins" / name).symlink_to(
                ROOT / "zsh/.oh-my-zsh/custom/plugins" / name, target_is_directory=True
            )
        env["ZSH_CUSTOM"] = str(custom)
        for cache_state in ["cold", "warm"]:
            with self.subTest(cache=cache_state):
                shell = self.shell(env)
                shell.expect("🤞")
                shell.send("stowed-complete comp\t\n")
                shell.expect("COMPLETED:completed-word\r\n")
                shell.expect("🤞")

    def test_lazy_carapace_tab_uses_programmable_completion(self):
        shell = self.shell(self.completion_env(with_carapace=True))
        shell.expect("🤞")
        shell.send("stowed-complete comp\t\n")
        shell.expect("COMPLETED:completed-word\r\n")
        shell.expect("🤞")

    def test_repeated_tabs_do_not_call_deleted_bootstrap(self):
        shell = self.shell(self.completion_env(with_carapace=True))
        (self.directory / "unique-fixture-file").write_text("FILE_COMPLETION_OK\n")
        shell.expect("🤞")
        for _ in range(2):
            shell.send("cat unique-fixt\t\n")
            shell.expect("FILE_COMPLETION_OK\r\n")
            shell.expect("🤞")
        self.assertNotIn(b"command not found", shell.transcript)

    def test_shells_keep_independent_modes_without_shared_cache(self):
        first = self.shell()
        first.expect("🤞")
        first.send("\x1b")
        first.expect("💪")
        second = self.shell()
        second.expect("🤞")
        # A redraw in shell one must still show command mode after shell two starts.
        first.send("\x0c")
        first.expect("💪")
        self.assertFalse((self.home / ".cache/vi_mode").exists())


if __name__ == "__main__":
    unittest.main()
