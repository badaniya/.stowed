# Herdr practical scrollback limit design

## Goal

Retain substantially more Herdr pane history without creating an impractical memory footprint when several panes are active.

## Decision

Set `scrollback_limit_bytes` to `4294967296` (4 GiB) in the `[advanced]` section of `~/.config/herdr/config.toml`.

## Rationale

The existing per-pane limit is 1,000,000,000 bytes. The host has 62 GiB RAM and 27 GiB available at inspection time, while its 4 GiB swap is fully used. A 4 GiB per-pane allocation gives long-running agents and commands much greater retained history while leaving practical capacity for several panes. Higher limits such as 8 GiB per pane make simultaneous output-heavy panes more likely to cause memory pressure or swapping.

## Scope

- Change only the existing `scrollback_limit_bytes` setting.
- Reload the running Herdr configuration.
- Verify that reload succeeds.

## Expected behavior

New output can be retained up to the 4 GiB per-pane cap. Existing scrollback need not expand retroactively.

## Validation

1. Confirm the configuration contains the 4 GiB value.
2. Run `herdr server reload-config` and confirm it succeeds.
3. Check `herdr status` for a healthy server after reload.
