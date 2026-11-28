# Portable deployment and private profiles

## Ownership

- Stow owns shared preferences, scripts and plugin declarations.
- Herdr owns installed plugins and runtime state; never link commands to installation-ID paths.
- `herdr-spreader/.local/bin/herdr-spreader` resolves Herdr's registered plugin binary on each invocation.
- Herdr Plus uses `~/.config/herdr/plugins/config/cloudmanic.herdr-plus/quick-actions`. The standalone fallback is one directory symlink to this canonical directory.
- Existing `~/.private_*` files stay outside Git. The private-links compatibility layer exposes selected files to applications without copying their contents into tracked configuration.

## New Linux host

Install prerequisites with your distribution package manager: GNU Stow, Git, Python 3, jq and ripgrep. Install Herdr using its official installer; make it available in PATH. Install the Rust/Go toolchains required by declared plugin builds (see the repository's mise configuration). Do not grant automatic sudo access to dotfiles scripts.

```sh
git clone https://github.com/badaniya/.stowed "$HOME/.stowed"
# Deploy shell/editor packages after reviewing Stow's conflict preview.
bash "$HOME/.stowed/scripts/setup-host.sh"
bash "$HOME/.stowed/scripts/bootstrap.sh"
bash "$HOME/.stowed/scripts/setup-host.sh" --check --profile public
```

Setup refuses conflicts instead of adopting/deleting files. The old generated standalone action mirror is renamed to a backup only after every entry is verified to resolve to the canonical action. The obsolete broken Spreader link is repaired only when its old target matches the known previous layout.

`setup-host.sh` deploys the three Herdr packages, not every editor/tool in the repository. Other packages remain opt-in. This is not a distribution-wide package installer.

## Private/work profile

Provision your existing private directories by encrypted transfer or from a separate encrypted private bundle before enabling work actions. Preserve their filenames; scripts never fetch credentials or choose an encryption identity for you. Use directory mode 0700 and secret file mode 0600. Never put SSH private keys or API tokens in the public checkout, command arguments, shell history or logs.

```sh
bash "$HOME/.stowed/scripts/private-links.sh"
DOTFILES_PROFILE=work bash "$HOME/.stowed/scripts/bootstrap.sh" --check
bash "$HOME/.stowed/scripts/setup-host.sh" --check --profile work
```

Public allows absent work data. Work requires the private launcher/action directories and private work environment; it validates permissions without displaying values. Missing dependencies and broken links fail checks. Credentials must be provisioned separately; a public Git clone cannot restore them.

Native per-file overlays remain preferred for Herdr actions and layouts. For applications that support native includes or merged configuration, use those contracts and document precedence. For other structured settings, generate an effective file outside the repository from public defaults and private overrides; use an atomic write, mode 0600, recursive object merge and explicit array replacement. Never concatenate JSON/YAML text or export effective secret-bearing files back to Git. A generic cross-application merge/encryption system is not installed by these scripts.

`.git/info/exclude` is convenience, not a security boundary: force-add bypasses it. Run a secret scanner before publishing changes and review staged filenames/diffs. Prefer an encrypted private repository or age-encrypted archive backed up separately. Do not assume ignored files are excluded from tar, rsync, or backups.

## Runtime migration (offline only)

The current folded Stow link remains valid. To move Herdr's sessions, plugin builds, caches and registry out of the checkout, quit Herdr yourself first. This will interrupt its sessions: plan downtime and save important work.

```sh
python3 "$HOME/.stowed/scripts/migrate-herdr-runtime.py"          # preview
python3 "$HOME/.stowed/scripts/migrate-herdr-runtime.py" --apply  # offline migration
bash "$HOME/.stowed/scripts/setup-host.sh" --check --profile work
```

Migration refuses a reachable Herdr server (and uncertain socket errors), copies state, retains the original top-level link as a backup, rewrites registry checkout prefixes to their new runtime location, preserves private symlinks and links only tracked shared configuration. Original runtime files stay in the checkout for recovery; remove them only after verifying the migrated installation. Do not run the server during migration.

`herdr/.stow-local-ignore` excludes runtime paths from later Stow operations. Do not use `stow --adopt` or whole-directory replacement after migration. Herdr-app runtime separation is not performed by this migration.

## Verification

```sh
python3 -m unittest discover -s tests/herdr -p portability_test.py
python3 -m unittest discover -s tests/herdr -p action_errors_test.py
bash scripts/bootstrap.sh --check
bash scripts/setup-host.sh --check --profile work
```

Checks do not install/update plugins or create private links. Herdr integration status can be reviewed with `herdr integration status`; install only integrations for agents you use. Bootstrap checks plugin pins and will reinstall declared GitHub plugins whose requested pin or enabled state differs. It does not stop or restart Herdr.
