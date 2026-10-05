# STOWED Herdr Launcher Design

## Goal

Update the STOWED herdr-spreader workspace launcher so it creates exactly one tab and starts Pi in it.

## Design

- Keep the existing `STOWED` workspace identity, root directory (`~/.stowed`), and focus behavior.
- Replace the current `1 - Config` tab and its `nvim` command with one `1 - Agent` tab whose only pane runs `pi`.
- Make no changes to the herdr-plus quick action; it continues to apply the same `stowed.yaml` launcher file.

## Error Handling

The launcher relies on existing herdr-spreader behavior. No new error paths or dependencies are introduced.

## Validation

- Parse the YAML configuration.
- Confirm it defines one STOWED workspace, one tab labeled `1 - Agent`, and a single pane command of `pi`.
