# Vim-test Go Module-Root Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every Go Vim-test invocation run from the closest enclosing Go module while preserving existing Herdr/Vimux strategies and non-Go behavior.

**Architecture:** Configure Vim-test's function-valued `g:test#project_root` with a Lua callback. For the active Go buffer, the callback finds the closest `go.mod` above the buffer path and returns its directory; otherwise it returns Neovim's existing working directory. Vim-test changes into that directory for command construction and execution, then restores the prior directory after the test run.

**Tech Stack:** Neovim Lua, `vim.fs.find`, vim-test, Go modules, Herdr/Vimux.

---

## File structure

- Modify: `nvim/.config/nvim/lua/custom/plugins/vim-test.lua` — retain existing Vim-test runner/strategy/keymap configuration and add the module-root callback.
- Create: `nvim/.config/nvim/tests/vim_test_module_root_spec.lua` — headless Lua regression test for Go module resolution and non-Go fallback.

### Task 1: Add a failing module-root resolver test

**Files:**
- Create: `nvim/.config/nvim/tests/vim_test_module_root_spec.lua`

- [ ] **Step 1: Write the failing test**

Create `nvim/.config/nvim/tests/vim_test_module_root_spec.lua` with a test harness that loads the resolver exported by the Vim-test plugin configuration and verifies the two repository modules plus a non-Go fallback:

```lua
local resolver = require('custom.vim-test-root').resolve
local go_switch_file = '/home/badaniya/workspace/badaniya/NVO-REVIEW/GoDCApp/GoSwitch/src/goswitch/test/campustest/voss/access_policy_test.go'
local nvo_test_file = '/home/badaniya/workspace/badaniya/NVO-REVIEW/GoDCApp/NVO/Test/src/test/network/functional/collectionactivity/collector_activity_test.go'

local function assert_equal(expected, actual)
  assert(expected == actual, ('expected %q, got %q'):format(expected, actual))
end

assert_equal(
  '/home/badaniya/workspace/badaniya/NVO-REVIEW/GoDCApp/GoSwitch/src/goswitch',
  resolver(go_switch_file, 'go', '/fallback')
)
assert_equal(
  '/home/badaniya/workspace/badaniya/NVO-REVIEW/GoDCApp/NVO/Test/src/test',
  resolver(nvo_test_file, 'go', '/fallback')
)
assert_equal('/fallback', resolver('/tmp/readme.md', 'markdown', '/fallback'))
print('vim-test module-root resolver tests passed')
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd /home/badaniya/.stowed
nvim --headless --clean -u NONE "+set rtp+=/home/badaniya/.config/nvim" "+luafile nvim/.config/nvim/tests/vim_test_module_root_spec.lua" +qa
```

Expected: failure because `custom.vim-test-root` does not yet exist.

### Task 2: Implement the reusable resolver and configure Vim-test

**Files:**
- Create: `nvim/.config/nvim/lua/custom/vim-test-root.lua`
- Modify: `nvim/.config/nvim/lua/custom/plugins/vim-test.lua:11-15`
- Test: `nvim/.config/nvim/tests/vim_test_module_root_spec.lua`

- [ ] **Step 1: Implement the minimal resolver**

Create `nvim/.config/nvim/lua/custom/vim-test-root.lua`:

```lua
local M = {}

function M.resolve(path, filetype, fallback)
  if filetype ~= 'go' or path == '' then
    return fallback
  end

  local go_mod = vim.fs.find('go.mod', { path = vim.fs.dirname(path), upward = true })[1]
  return go_mod and vim.fs.dirname(go_mod) or fallback
end

function M.current_buffer_root()
  local buffer = vim.api.nvim_get_current_buf()
  return M.resolve(
    vim.api.nvim_buf_get_name(buffer),
    vim.bo[buffer].filetype,
    vim.fn.getcwd()
  )
end

return M
```

- [ ] **Step 2: Configure Vim-test to call the resolver**

In `nvim/.config/nvim/lua/custom/plugins/vim-test.lua`, immediately after the existing `vim.g['test#go#runner'] = 'gotest'` line, add:

```lua
    vim.g['test#project_root'] = function()
      return require('custom.vim-test-root').current_buffer_root()
    end
```

Do not change the existing strategy selection, Go test options, or keymaps.

- [ ] **Step 3: Run the resolver test to verify it passes**

Run:

```bash
cd /home/badaniya/.stowed
nvim --headless --clean -u NONE "+set rtp+=/home/badaniya/.config/nvim" "+luafile nvim/.config/nvim/tests/vim_test_module_root_spec.lua" +qa
```

Expected: `vim-test module-root resolver tests passed` and exit status 0.

- [ ] **Step 4: Run Lua diagnostics**

Run:

```text
lens_diagnostics(source='lsp', scope='paths', mode='full', path='/home/badaniya/.stowed/nvim/.config/nvim/lua/custom/vim-test-root.lua', paths=['/home/badaniya/.stowed/nvim/.config/nvim/lua/custom/vim-test-root.lua', '/home/badaniya/.stowed/nvim/.config/nvim/lua/custom/plugins/vim-test.lua'])
```

Expected: no error-level diagnostics.

- [ ] **Step 5: Commit the implementation**

```bash
cd /home/badaniya/.stowed
git add nvim/.config/nvim/lua/custom/vim-test-root.lua nvim/.config/nvim/lua/custom/plugins/vim-test.lua nvim/.config/nvim/tests/vim_test_module_root_spec.lua
git commit -m "nvim: run Vim-test Go commands from module root"
```

### Task 3: Validate Vim-test command behavior in a fresh Neovim session

**Files:**
- Modify: none
- Test: `nvim/.config/nvim/tests/vim_test_module_root_spec.lua`

- [ ] **Step 1: Start a fresh Neovim session from the GoDCApp workspace**

Run:

```bash
cd /home/badaniya/workspace/badaniya/NVO-REVIEW/GoDCApp
nvim GoSwitch/src/goswitch/test/campustest/voss/access_policy_test.go
```

- [ ] **Step 2: Verify GoSwitch nearest-test dispatch**

In Neovim, place the cursor inside `Test_Campus_AccessPolicy_SET_GET` and run:

```vim
:TestNearest
```

Expected: the Herdr/Vimux command starts with a directory change to `GoSwitch/src/goswitch`, then invokes `go test` with `-tags ci_jenkins`; the test runs without a missing-module error.

- [ ] **Step 3: Verify NVO Test nearest-test dispatch**

Open:

```vim
:e NVO/Test/src/test/network/functional/collectionactivity/collector_activity_test.go
```

Place the cursor in a test and run:

```vim
:TestNearest
```

Expected: the dispatched command runs from `NVO/Test/src/test`, using that module's `go.mod`.

- [ ] **Step 4: Verify non-Go fallback and restored directory**

In the same Neovim session, open a non-Go file and run a supported Vim-test command if available. Before and after each Vim-test command, run:

```vim
:pwd
```

Expected: non-Go commands use the pre-existing working directory, and after each Vim-test run Neovim reports the original working directory.
