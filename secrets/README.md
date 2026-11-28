# Consolidated plain pass credentials

This package uses **pass/password-store**, not gopass. It keeps `gh` as the CLI and supplies a token to one child process, without native gh token storage, Secret Service or GNOME Keyring.

## Deploy

Install the standard password-store package with your OS package manager (Ubuntu: `sudo apt install pass`), then deploy this package:

```sh
stow --simulate -d "$HOME/.stowed" -t "$HOME" secrets
stow -d "$HOME/.stowed" -t "$HOME" secrets
```

Copy `~/.config/dotfiles-secrets/accounts.example.json` to `~/.private_gh_accounts.json`, configure the real enterprise host, and restrict the file to mode 0600. It contains host names and pass references only, never token values. Keep it outside the public repository.

## Protected key and store setup

`setup-secrets-key` prompts privately in your terminal for a nonempty passphrase, generates a per-host Ed25519 signing/certification key and CV25519 encryption subkey (one-year expiry), verifies protected private-key storage, and runs `pass init`. It refuses to replace an existing store or secret GPG keys. Passphrases go through stdin, never arguments, environment variables or a plaintext file.

```sh
setup-secrets-key
```

The store is `~/.password-store`, outside the public dotfiles repository. Back up private key material securely before relying on the store. Losing the decryption key can make credentials unrecoverable. One-year expiry requires renewal for continued encryption; it does not delete existing data. A shared store can later use both hosts' public encryption keys as recipients without copying private keys between hosts.

If you already have an appropriate protected GPG key, select it deliberately with `pass init KEY_ID` instead. Do not create an unprotected production key.

For the shared private Git vault, scope entries to each host and set the corresponding references in `~/.private_gh_accounts.json`:

- `hosts/HOSTNAME/github/personal/token`
- `hosts/HOSTNAME/github/work/token`
- `hosts/HOSTNAME/github/enterprise/token`

Each host directory has its own `.gpg-id` recipient. The repository contains the participating public keys, but private keys stay on their own hosts. Root recipients can be used for explicitly shared entries; do not place host-specific tokens at the root.

Use `pass git pull --ff-only` before editing and `pass git push` after edits. Different host namespaces reduce conflicts, but Git synchronization is explicit and may require conflict resolution.

## Docker credentials in the same store

`docker-credential-private-pass` routes the existing `docker-credential-pass` executable to `~/.password-store/hosts/HOSTNAME`. Configure Docker's `credsStore` as `private-pass` when using this adapter. It preserves Docker's stdin/stdout credential protocol; do not manually run its `get` command in an agent transcript because the backend returns secret material to its caller.

The existing encrypted Docker entries can be relocated under the host namespace without decrypting or re-encrypting them. Keep an inactive recovery copy until verification. The consolidated active store remains `~/.password-store`; no second active vault is required.

Because the adapter uses a nested pass prefix, Docker changes may need explicit staging/committing at the vault root. Review `pass git status`, then commit encrypted changes and run `pass git push` when VPN connectivity is available. Neither credential retrieval nor Docker helper operations automatically pull or push the vault.

The adapter requires the original `docker-credential-pass` executable on PATH and a host `.gpg-id`; it fails without changing credentials if either is missing.

## Recovery backup

Run `pass-recovery-backup` in your terminal and enter the existing GPG passphrase privately. It creates a passphrase-encrypted bundle under `~/.private-pass-recovery/HOSTNAME`, checks that it decrypts, and restores the key in a disposable keyring to verify decryption. Private key exports are handled in memory rather than written as plaintext export files. The bundle uses the same GPG passphrase and contains the private/public key and revocation certificate when available.

Keep the encrypted bundle off the VM, separate from the public dotfiles repo and vault Git repository. Confirm the off-host copy and remember its passphrase before deleting any existing credentials.

Do not print tokens, paste them into agent chat, put them in arguments, or write temporary plaintext token files. Existing credentials must be imported in a separately verified migration; do not remove native gh tokens or profile exports until the replacement works.

## Usage

```sh
gh-personal api user
gh-work api user
gh-enterprise api user
```

Wrappers clear inherited GitHub token overrides, set the selected host, and capture `pass show` output privately. The referenced entry must contain only the token, on one line. No fuzzy lookup or automatic network synchronization is used. Missing/locked stores and invalid entries fail without displaying provider output or falling back to native gh credentials. Arguments are passed directly without shell evaluation.

Native gh login, logout, refresh, switch, setup-git and token printing are blocked through these launchers. Normal `gh` remains unchanged during migration. Same-user/root processes may access credentials while the child runs; these wrappers are not an isolation boundary against a compromised account.

This stage covers gh commands only. Git credential helpers and Herdr scripts that call `gh auth token --user ...` must be adapted before native gh credentials are removed. The account's token must have the required permissions and SSO authorization.

The host checks prevent common accidental cross-host use; they are not a general sandbox for arbitrary gh subcommands or request bodies. For background jobs, arrange a deliberate GPG unlock session—never store an unlock password beside the encrypted store.

## Verification

```sh
python3 -m unittest discover -s tests/secrets -p '*_test.py'
```

Tests use synthetic credentials, mocked key setup, and disposable GPG keys for a real recovery round trip. No production keys or tokens are used.
