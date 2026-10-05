# STOWED Agent Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure the STOWED herdr-spreader launcher to create exactly one `1 - Agent` tab running Pi.

**Architecture:** The existing herdr-plus quick action remains unchanged and continues to apply `/home/badaniya/.config/herdr/plugins/config/herdr-spreader/stowed.yaml`. The YAML workspace definition retains its workspace metadata while replacing the one tab/pane command.

**Tech Stack:** YAML, herdr-spreader, Herdr, Pi CLI

---

### Task 1: Update the STOWED workspace layout

**Files:**
- Modify: `herdr/.config/herdr/plugins/config/herdr-spreader/stowed.yaml:1-8`
- Test: `herdr/.config/herdr/plugins/config/herdr-spreader/stowed.yaml:1-8`

- [ ] **Step 1: Establish the expected launcher structure**

The finished YAML must be exactly:

```yaml
workspaces:
  - name: STOWED
    root: ~/.stowed
    focus: true
    tabs:
      - label: 1 - Agent
        panes:
          - command: pi
```

- [ ] **Step 2: Confirm the current configuration differs**

Run:

```bash
rg -n 'label: 1 - Config|command: nvim' herdr/.config/herdr/plugins/config/herdr-spreader/stowed.yaml
```

Expected: matches for the old `1 - Config` label and `nvim` command before the edit.

- [ ] **Step 3: Replace the sole tab label and pane command**

Change `herdr/.config/herdr/plugins/config/herdr-spreader/stowed.yaml` so its sole tab uses:

```yaml
      - label: 1 - Agent
        panes:
          - command: pi
```

Keep `workspaces`, `name: STOWED`, `root: ~/.stowed`, and `focus: true` unchanged.

- [ ] **Step 4: Parse and assert the final YAML contract**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import yaml

layout = yaml.safe_load(Path('herdr/.config/herdr/plugins/config/herdr-spreader/stowed.yaml').read_text())
workspaces = layout['workspaces']
assert len(workspaces) == 1
workspace = workspaces[0]
assert workspace['name'] == 'STOWED'
assert workspace['root'] == '~/.stowed'
assert workspace['focus'] is True
assert workspace['tabs'] == [{'label': '1 - Agent', 'panes': [{'command': 'pi'}]}]
print('STOWED launcher validated')
PY
```

Expected: `STOWED launcher validated`.

- [ ] **Step 5: Commit the launcher update**

```bash
git add herdr/.config/herdr/plugins/config/herdr-spreader/stowed.yaml
git commit -m "herdr: launch Pi in STOWED workspace"
```
