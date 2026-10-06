# Vim-test Go Module-Root Design

## Goal

Make Vim-test run Go tests from the nearest enclosing `go.mod` while preserving its existing Herdr/Vimux strategy and non-Go behavior.

## Scope

- Cover `:TestNearest`, `:TestFile`, and `:TestSuite`, including their existing `<leader>vn`, `<leader>vf`, and `<leader>vs` mappings.
- Resolve the module root from the active Go buffer on every test invocation.
- Use the existing Go test options, including `-tags ci_jenkins`.
- Leave non-Go test execution rooted at Neovim's current working directory.

## Design

Configure Vim-test's function-valued `g:test#project_root` in `nvim/.config/nvim/lua/custom/plugins/vim-test.lua`.

The callback will:

1. Read the current buffer's filetype and absolute path.
2. Return the current Neovim working directory unless the buffer is a Go file with a path.
3. For Go, search upward from the file directory for `go.mod` with `vim.fs.find`.
4. Return the directory containing the closest `go.mod`; if none is found, fall back to the original working directory.

Vim-test changes to the callback's result before building and dispatching its command, then restores the original working directory after the run. This preserves the editor state while making each Go command module-aware.

## Expected module roots

- GoSwitch tests: `GoSwitch/src/goswitch/go.mod`
- NVO Test network tests: `NVO/Test/src/test/go.mod`

## Validation

1. Confirm the resolver returns `GoSwitch/src/goswitch` for a GoSwitch test buffer.
2. Confirm it returns `NVO/Test/src/test` for an NVO Test network test buffer.
3. Run a representative nearest test from each module through Vim-test.
4. Confirm the working directory is restored after each run.
5. Confirm a non-Go buffer falls back to the original current directory.
