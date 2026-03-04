# Neovim Configuration Knowledge Base

**Generated:** 2026-02-08T19:59:48Z
**Base:** kickstart.nvim + lazy.nvim

## Overview

Modular nvim config with 40+ custom plugins. Entry point: `init.lua` (1177 lines). Custom plugins auto-loaded from `lua/custom/plugins/`.

## Structure

```
nvim/.config/nvim/
├── init.lua              # Main config: LSP, keybindings, base plugins
├── lazy-lock.json        # Plugin version lock
├── .stylua.toml          # Lua formatter config
├── lua/
│   ├── kickstart/        # Base framework (7 files, don't modify)
│   │   └── plugins/      # indent_line, debug, gitsigns, autopairs, lint, neo-tree
│   └── custom/
│       ├── plugins/      # 40 plugin configs (one file per plugin)
│       └── mcpserver/    # Custom MCP tools (mytime.lua)
```

## Where to Look

| Task | Location |
|------|----------|
| Add new plugin | Create `lua/custom/plugins/<name>.lua` |
| Edit global keybindings | `init.lua` lines 101-145 |
| Edit which-key groups | `init.lua` lines 266-299 |
| Configure LSP server | `init.lua` lines 492-530 (servers table) |
| Add completion source | `lua/custom/plugins/blink-cmp.lua` |
| Add AI tool | `lua/custom/mcpserver/` or extend codecompanion/avante |

## Plugin Spec Pattern

All custom plugins follow lazy.nvim format:

```lua
return {
  'owner/plugin-name',
  version = '1.*',                    -- Optional version constraint
  event = 'VeryLazy',                 -- Lazy load trigger
  dependencies = { 'dep/plugin' },    -- Sub-dependencies
  opts = { ... },                     -- Config table (merged with setup)
  config = function() ... end,        -- Custom setup
  keys = {                            -- Keybindings
    { '<leader>x', '<cmd>Cmd<cr>', desc = 'Description' },
  },
}
```

## Keybinding Conventions

**Leader**: Space

| Prefix | Domain |
|--------|--------|
| `<leader>a` | Avante AI |
| `<leader>C` | CodeCompanion AI |
| `<leader>c` | Code operations |
| `<leader>d` | Document/text |
| `<leader>f` | Find/search |
| `<leader>g` | Git |
| `<leader>l` | LSP |
| `<leader>S` | Sidekick AI |
| `<leader>t` | Trouble diagnostics |
| `<leader>u` | User toggles |
| `<leader>w` | Workspace |

**Navigation**: `Ctrl+h/j/k/l` for tmux-nvim pane switching

## Completion Stack (blink-cmp)

Sources in priority order:
1. avante (AI suggestions)
2. lsp
3. path
4. snippets
5. buffer
6. copilot (score_offset=100)
7. emoji, git, spell

## AI Plugins

| Plugin | Purpose |
|--------|---------|
| avante.lua | Agentic AI with Claude/Copilot, diff preview |
| codecompanion.lua | Chat interface with history, MCP tools |
| copilot.lua | GitHub Copilot completion |
| copilot-chat.lua | Copilot chat interface |
| sidekick.lua | Bridge to CLI AI (Goose, OpenCode) via tmux |
| mcphub.lua | MCP server hub for AI tool access |

## Formatting

Enforced by `.stylua.toml`:
- **Line width**: 160 chars
- **Indent**: 2 spaces
- **Quotes**: Single preferred
- **Parentheses**: None where optional

```bash
# Check formatting
stylua --check .

# Auto-fix
stylua .
```

## Anti-Patterns

| Forbidden | Do Instead |
|-----------|------------|
| Edit `lua/kickstart/` | Create override in `lua/custom/plugins/` |
| `as any` / `@ts-ignore` in plugins | Fix the type properly |
| Keybindings without `desc` | Always add description for which-key |
| Hardcoded paths | Use `vim.fn.stdpath()` or env vars |

## LSP Configuration

New servers go in `init.lua` servers table (line 492):

```lua
local servers = {
  gopls = {},
  pyright = {},
  lua_ls = {
    settings = {
      Lua = { ... }
    },
  },
  -- Add new server here
}
```

Auto-installed via mason-tool-installer.

## Complex Plugins (>300 lines)

| File | Lines | Key Features |
|------|-------|--------------|
| snacks.lua | 896 | Dashboard, 100+ picker keybindings, notifications |
| markdown-render.lua | 434 | LaTeX, callouts, table styling |
| obsidian.lua | 350 | Workspaces, daily notes, wiki links |
| flash.lua | 305 | 4 search modes, treesitter integration |
| codecompanion.lua | 299 | Multi-adapter, MCP tools, history |

## Notes

- Uses Neovim 0.11+ `vim.lsp.config()` pattern
- Catppuccin mocha theme with custom highlights
- WSL-specific clipboard handling in init.lua
- `GIT_DEV_REPO_PATH` env var set by zsh for AI context
