# .stowed Repository Knowledge Base

**Generated:** 2026-02-08T19:59:48Z
**Commit:** a0da805e
**Branch:** main

## Overview

GNU Stow-managed dotfiles repository. 23 packages covering shells (bash/zsh), editors (nvim/vim/emacs), terminal tools (tmux/fzf/bat/delta), and AI assistants (copilot/goose/opencode). Uses git subtrees for plugin management.

## Structure

```
.stowed/
├── bash/           # .bashrc, .bash_functions.sh, .bash_aliases
├── zsh/            # .zshrc, .zsh_functions.zsh, .oh-my-zsh/ (subtree)
├── nvim/           # .config/nvim/ - kickstart.nvim + 40 custom plugins
├── vim/            # .vimrc, .vim/plugged/ (subtrees)
├── emacs/          # .emacs.d/
├── tmux/           # .tmux.conf, .tmux/plugins/ (11 subtrees)
├── fzf/            # .fzf/ (subtree)
├── bat/, delta/    # Syntax highlighting, git diff theming
├── starship/       # Shell prompt config
├── ghostty/        # Terminal emulator config
├── copilot/, goose/, opencode/, mcphub/, vectorcode/  # AI tools
└── tmuxinator/, gitui/, lazygit/, kubecolor/          # Optional tools
```

## Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Add shell alias | `bash/.bash_aliases` | Sourced by both bash and zsh |
| Add shell function | `bash/.bash_functions.sh` (shared) or `zsh/.zsh_functions.zsh` (zsh-only) | |
| Add nvim plugin | `nvim/.config/nvim/lua/custom/plugins/<name>.lua` | One file per plugin |
| Edit nvim keybindings | `nvim/.config/nvim/init.lua` lines 101-145, 266-299 | Or in plugin `keys = {}` |
| Add tmux plugin | `nested_git_repos.md` → git subtree commands | Never edit subtrees directly |
| Configure AI tools | `copilot/.config/.copilot/`, `goose/.config/goose/`, `opencode/.config/opencode/` | |
| Update git subtree | `git subtree pull --prefix=<path> <remote> <branch> --squash` | See `nested_git_repos.md` |

## Commands

```bash
# Stow a package (create symlinks)
stow -d $HOME/.stowed <package-name>

# Format nvim lua files
stylua --check . && stylua .   # from nvim/.config/nvim/

# Check shell scripts
shellcheck <script.sh>

# Rebuild bat cache after theme changes
bat cache --build

# Update a git subtree
git subtree pull --prefix=zsh/.oh-my-zsh oh-my-zsh master --squash
```

## Conventions

### Indentation
- **2 spaces**: Shell, Lua, YAML, TOML, config files
- **4 spaces**: Python only

### Lua (Neovim)
- 160 char line width, single quotes preferred
- No call parentheses where optional (stylua enforced)
- See `nvim/.config/nvim/.stylua.toml`

### Shell Scripts
- Quote variables: `"$variable"` not `$variable`
- Use bash built-ins over external commands
- Error handling: `set -e` or explicit checks
- Functions over duplicated code

### Commit Messages
- Format: `component: description`
- Examples: `nvim: add codecompanion keybinding`, `zsh: update oh-my-zsh subtree`
- Explain WHY, not WHAT

## Anti-Patterns (NEVER do these)

| Forbidden | Why |
|-----------|-----|
| Use `grep` | Use `rg` (ripgrep) instead |
| Edit git subtree content directly | Update via `git subtree pull` only |
| Commit generated files | Session.vim, .cache/, .lsp-session-v1, eln-cache/ |
| Suppress Lua type errors | No `---@diagnostic disable` without justification |
| Override `TERM=tmux-256color` | Breaks nvim image rendering in tmux |

## Tool Integrations

### Tmux ↔ Neovim
- `vim-tmux-navigator`: Ctrl+h/j/k/l for seamless pane navigation
- `tmux-resurrect`: Auto-restores nvim sessions (`@resurrect-strategy-nvim 'session'`)

### FZF ↔ Bat ↔ Delta
- `FZF_PREVIEW_COLUMNS` env var shared across tools for dynamic sizing
- Delta uses bat syntax themes for git diffs

### Shell ↔ Bash/Zsh Sharing
- `.bash_aliases` sourced by both shells
- `.bash_profile` sets `EDITOR=nvim`, `GOPATH`, `PATH` extensions
- Private overrides: `~/.private_bash_aliases`, `~/.private_bash_functions`

### AI Tools
- `GIT_DEV_REPO_PATH` set by zsh preexec hook when nvim launches
- Goose config templated via `envsubst` before execution
- MCP servers configured in `copilot/.config/.copilot/mcp-config.json`

## Theme

**Catppuccin Mocha** across all tools:
- Shell: starship prompt, zsh-syntax-highlighting, LS_COLORS
- Editor: nvim colorscheme, tmux status bar
- Git: delta diff theme

## Git Subtrees

Managed external plugins (never edit directly):

| Package | Subtrees |
|---------|----------|
| tmux | tpm, tmux-sensible, tmux-yank, vim-tmux-navigator, tmux-resurrect, tmux-continuum, tmux-thumbs, tmux-floax, tmux-fzf-url, catppuccin, tmux-cpu |
| zsh | oh-my-zsh, zsh-syntax-highlighting, zsh-autosuggestions, zsh-vi-mode, forgit, tmux-xpanes, last-working-dir-tmux |
| vim | ferret, lightline.vim, nerdtree, nerdtree-git-plugin, vim-fugitive, vim-gitgutter, vim-go |
| fzf | fzf |

Full commands in `nested_git_repos.md`.

## Notes

- Node.js version pinned in `.nvmrc` (v24.9.0)
- Emacs uses symlink: `.emacs → .emacs.d/init.el`
- Shell functions duplicated between bash/zsh - maintain both when editing
- Nvim has dedicated AGENTS.md at `nvim/.config/nvim/AGENTS.md`
