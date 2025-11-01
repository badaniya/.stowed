# Agent Guidelines for .stowed Repository

This is a dotfiles repository managed with GNU Stow containing shell configurations (bash/zsh), editor setups (nvim/vim/emacs), and terminal tool configs.

## Build/Lint/Test Commands
- Stow symlinks: `stow -d $HOME/.stowed <package-name>`
- Lua format (Neovim): `stylua --check .` or `stylua .` (from nvim/.config/nvim/)
- Build bat cache: `bat cache --build`
- Shell script check: Use `shellcheck` on .sh files
- Single test: N/A (this is a config repository, not a code project)

## Code Style Guidelines
**General:**
- Use `rg` (ripgrep) for search, never `grep`
- Unix line endings (LF), UTF-8 encoding
- Insert final newline in all files
- Don't commit generated files (Session.vim, .cache/, .lsp-session-v1)

**Indentation:**
- Default: 2 spaces (shell scripts, Lua, YAML, config files)
- Python: 4 spaces
- Follow existing file's style if different

**Lua (Neovim config):**
- 2-space indentation, 160 char line width
- Single quotes preferred (stylua: AutoPreferSingle)
- No call parentheses where optional (stylua setting)
- Functions focused and clear
- Comment complex keybindings and plugin configs

**Shell Scripts (bash/zsh):**
- Use bash built-ins over external commands where possible
- Quote variables: `"$variable"` not `$variable`
- Check errors: `set -e` or explicit checks
- Functions over duplicated code

**Git Subtrees:**
- This repo uses git subtrees for nested plugins/tools
- Never directly edit subtree content - update via `git subtree pull`
- See nested_git_repos.md for maintenance

**Commit Messages:**
- Clear, concise, explain WHY not WHAT
- Format: "component: description" (e.g., "nvim: add codecompanion keybinding")