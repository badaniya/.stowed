# Machine-bound automatic pass unlock

This opt-in mode replaces a second interactive GPG-password step with trust in the machine and authenticated OS account. It does not remove GPG key passphrases or export private keys.

## Security boundary

- A root-owned helper stores the unlock payload only as a `systemd-creds` encrypted credential under `/var/lib/dotfiles-secrets-auto-unlock/`.
- TPM-capable hosts require `host+tpm2`; other hosts use a root-owned host key. There is no silent TPM-to-host fallback.
- Without TPM or underlying disk encryption, a complete disk/VM snapshot can expose both the host key and encrypted credential. Root compromise permits automatic unlock by design.
- The narrowly authorized helper presets only the enrolled user's encryption-key grips. It never prints the unlock passphrase. Enrollment passes it through memory and stdin pipes, never argv, environment, or plaintext files.
- The restricted sudo rule disables input/output logging for this helper. OS-level privileged tracing remains outside this protection.
- A PAM **optional session** hook unlocks after login; it does not authenticate users or deny login if unlock fails. A shell-profile hook also covers environments that do not run PAM sessions.
- GitHub, Jira and Docker launchers refill the cache on demand. Interactive `pass` is routed through `pass-unlocked` by a shell alias.
- GPG has no documented forever-TTL setting. Enrollment sets both TTLs to 2,147,483,647 seconds, exceeding a practical agent lifetime; on-demand refill also covers agent restarts.

## Install and enroll

Install the `secrets` package's entrypoints, then run:

```bash
~/.local/bin/setup-pass-auto-unlock --fingerprint YOUR_PRIMARY_FINGERPRINT
~/.local/bin/enroll-pass-auto-unlock --fingerprint YOUR_PRIMARY_FINGERPRINT
```

Installation requires administrative permission. Enrollment must run in an interactive terminal. Enter the existing GPG passphrase privately once. It validates decryption of the shared Jira ciphertext without printing the token, seals the unlock payload, clears the prior cache and verifies automatic refill.

Enrollment requires the shared `jira/work/token` ciphertext and Python 3. It does not synchronize GPG private keys or host-bound unlock credentials.

## Verify

```bash
sudo -n /usr/local/libexec/dotfiles-secrets-auto-unlock --status
~/.local/bin/pass-auto-unlock
```

Test agent-cache loss or reboot only during an approved maintenance window. Do not kill another person's agent processes to test this.

Credential commands fail closed if an enrolled machine credential cannot be decrypted. Firmware/TPM policy changes, machine-key loss or encryption-key rotation may require deliberate re-enrollment. Signing/certification key grips are not preset.

## Rollback

Remove the enrolled user's root credential through an administrator, remove that user's restricted sudo rule, remove the optional PAM line and marked shell-profile block, and restore the backed-up GPG agent configuration. Existing encrypted recovery bundles and original key protection remain necessary.
