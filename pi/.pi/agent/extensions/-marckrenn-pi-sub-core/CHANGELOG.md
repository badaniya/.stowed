# @marckrenn/pi-sub-core

## 1.3.0

### Minor Changes

- [#42](https://github.com/marckrenn/pi-sub/pull/42) [`8bf29f3`](https://github.com/marckrenn/pi-sub/commit/8bf29f34c8f9418284cf30631a3325799c3e0f48) Thanks [@marckrenn](https://github.com/marckrenn)! - - Added an optional `showContextBar` setting (default: off), as introduced in [#10](https://github.com/marckrenn/pi-sub/pull/10) by [@pasky](https://github.com/pasky), to render the current context usage as an optional leftmost `Ctx` bar in sub-bar usage output.
  - Support for Codex Spark usage (auto-selected for `gpt-5.3-codex-spark`), including model-specific window labeling behavior.
  - OpenAI Status provider now surfaces the Codex-specific status endpoint instead of the generic status summary when available.
  - [`80b49b1`](https://github.com/marckrenn/pi-sub/commit/80b49b16c20c942135764bcf6c4cd0516e868ce2) Fixed API key auth format handling for the z.ai provider.

### Patch Changes

- Updated dependencies [[`8bf29f3`](https://github.com/marckrenn/pi-sub/commit/8bf29f34c8f9418284cf30631a3325799c3e0f48)]:
  - @marckrenn/pi-sub-shared@1.3.0

## 1.2.0

### Patch Changes

- Fixed tool registration execute signature order for compatibility with the latest Pi tool API.

### Updated dependencies:

- @marckrenn/pi-sub-shared@1.2.0

## 1.1.0

### Patch Changes

- [`7ce2a92`](https://github.com/marckrenn/pi-sub/commit/7ce2a92b15e766fd85a4b7eb85d6fc5c5aa32dca) Thanks [@marckrenn](https://github.com/marckrenn)! - Support providing credentials via environment variables for the usage providers (Anthropic, Copilot, Gemini, Antigravity, Codex, z.ai).

- Updated dependencies []:
  - @marckrenn/pi-sub-shared@1.1.0

## 1.0.6

### Patch Changes

- Watch `~/.pi/agent/pi-sub-core-settings.json` for changes and hot-reload settings (with `fs.watch` + polling fallback).

- Updated dependencies []:
  - @marckrenn/pi-sub-shared@1.0.6

## 1.0.5

### Patch Changes

- [#35](https://github.com/marckrenn/pi-sub/pull/35) [`59e2b45`](https://github.com/marckrenn/pi-sub/commit/59e2b456e0e5c41479dccedcef93f9175cc4aa55) Thanks [@marckrenn](https://github.com/marckrenn)! - Improve startup responsiveness by deferring refreshes and watchers, skipping headless UI work, and unref-ing long-lived timers so pi CLI commands exit cleanly.

- Updated dependencies [[`59e2b45`](https://github.com/marckrenn/pi-sub/commit/59e2b456e0e5c41479dccedcef93f9175cc4aa55)]:
  - @marckrenn/pi-sub-shared@1.0.5

## 1.0.4

### Patch Changes

- [#30](https://github.com/marckrenn/pi-sub/pull/30) [`af0828a`](https://github.com/marckrenn/pi-sub/commit/af0828a8d2e529497a1acff95e388a0a3eabb90e) Thanks [@marckrenn](https://github.com/marckrenn)! - Store the shared cache and lock files in the agent directory so all sub-core instances share a single cache.

- [#22](https://github.com/marckrenn/pi-sub/pull/22) [`3e5a026`](https://github.com/marckrenn/pi-sub/commit/3e5a026ea3dc113561ff32466a8aa03b91c6d876) Thanks [@marckrenn](https://github.com/marckrenn)! - Store sub-core and sub-bar settings in agent-level JSON files so updates no longer overwrite user configuration. Legacy extension `settings.json` files are migrated into the new files and removed after a successful migration.

  Manual migration (if you want to do it yourself before updating):

  ```
  cp ~/.pi/agent/extensions/sub-core/settings.json ~/.pi/agent/pi-sub-core-settings.json
  cp ~/.pi/agent/extensions/sub-bar/settings.json ~/.pi/agent/pi-sub-bar-settings.json
  ```

  Existing users should move legacy settings from the extension folders to:
  - `~/.pi/agent/pi-sub-core-settings.json`
  - `~/.pi/agent/pi-sub-bar-settings.json`

- [`a6c0d33`](https://github.com/marckrenn/pi-sub/commit/a6c0d33c8d19d2876a4a8a1a0a69302a3c63f5e8) Thanks [@marckrenn](https://github.com/marckrenn)! - Move the shared cache/lock files under `~/.pi/agent/cache/sub-core` so all clients share a single cache directory.

- [`7da1e08`](https://github.com/marckrenn/pi-sub/commit/7da1e082e634f4e4dee2560b4d490527d1543ade) Thanks [@marckrenn](https://github.com/marckrenn)! - Add a minimum refresh interval setting to cap refresh frequency even when refresh is triggered every turn.

- [`1f5e451`](https://github.com/marckrenn/pi-sub/commit/1f5e45173b9868b0d6645ae35a084142a0ac56a5) Thanks [@marckrenn](https://github.com/marckrenn)! - Gate tool registration behind `tools.usageTool` and `tools.allUsageTool` (default off) in sub-core settings.

- [`35eb185`](https://github.com/marckrenn/pi-sub/commit/35eb18590f369db4cda931b8e11099d0f3ddb4ec) Thanks [@marckrenn](https://github.com/marckrenn)! - Add usage tool aliases `get_current_usage` and `get_all_usage`.

- Updated dependencies [[`7da1e08`](https://github.com/marckrenn/pi-sub/commit/7da1e082e634f4e4dee2560b4d490527d1543ade)]:
  - @marckrenn/pi-sub-shared@1.0.4

## 1.0.3

### Patch Changes

- [`6fa2736`](https://github.com/marckrenn/pi-sub/commit/6fa27363573f34c38a372a6d7b8b74e756716724) Thanks [@marckrenn](https://github.com/marckrenn)! - Update extension tool execute signature order for compatibility with latest Pi API.

- Updated dependencies [[`6fa2736`](https://github.com/marckrenn/pi-sub/commit/6fa27363573f34c38a372a6d7b8b74e756716724)]:
  - @marckrenn/pi-sub-shared@1.0.3

## 1.0.2

### Patch Changes

- [#3](https://github.com/marckrenn/pi-sub/pull/3) [`4ceb5ad`](https://github.com/marckrenn/pi-sub/commit/4ceb5ad133166237652d197ba9296ad1589a813c) Thanks [@marckrenn](https://github.com/marckrenn)! - Bundle sub-core with sub-bar, refresh Antigravity quotas + settings, and update UI copy/controls.

- Updated dependencies [[`4ceb5ad`](https://github.com/marckrenn/pi-sub/commit/4ceb5ad133166237652d197ba9296ad1589a813c)]:
  - @marckrenn/pi-sub-shared@1.0.2

## 1.0.1

### Patch Changes

- Align repo version with npm publish.
- Updated dependencies:
  - @marckrenn/pi-sub-shared@1.0.1

## 1.0.0

### Major Changes

- [`9bedd80`](https://github.com/marckrenn/pi-sub/commit/9bedd80b0037b723e70f0376019fff59a617e7cb) Thanks [@marckrenn](https://github.com/marckrenn)! - Initial 1.0.0 release.

### Patch Changes

- Updated dependencies [[`9bedd80`](https://github.com/marckrenn/pi-sub/commit/9bedd80b0037b723e70f0376019fff59a617e7cb)]:
  - @marckrenn/pi-sub-shared@1.0.0
