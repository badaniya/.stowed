[Go Back to the Main README](README.md)

## How Nested Git Repositories Are Configured - For Reference ONLY

This document records the current git subtree configuration for this dotfiles repo.
Run these commands to re-establish remotes and subtrees on a fresh clone, or to update
existing subtrees.

### General Subtree Maintenance

```bash
# List existing remotes
git remote -v

# Update a subtree to latest upstream
git subtree pull --prefix=<prefix path> <remote name> <branch name> --squash

# Add a new subtree (if not already present)
git subtree add --prefix=<prefix path> <remote name> <branch name> --squash
```

---

### 1) tmux Plugins (11 subtrees)

```bash
cd $HOME/.stowed

# Add remotes (idempotent)
git remote add tpm https://github.com/tmux-plugins/tpm
git remote add tmux-sensible https://github.com/tmux-plugins/tmux-sensible
git remote add tmux-yank https://github.com/tmux-plugins/tmux-yank
git remote add vim-tmux-navigator https://github.com/christoomey/vim-tmux-navigator
git remote add tmux-resurrect https://github.com/tmux-plugins/tmux-resurrect
git remote add tmux-continuum https://github.com/tmux-plugins/tmux-continuum
git remote add tmux-thumbs https://github.com/fcsonline/tmux-thumbs
git remote add tmux-floax https://github.com/omerxx/tmux-floax
git remote add tmux-fzf-url https://github.com/wfxr/tmux-fzf-url
git remote add tmux-cpu https://github.com/tmux-plugins/tmux-cpu

# NOTE: catppuccin theme is bundled in the tmux plugin at tmux/.tmux/plugins/tmux/
# No separate subtree needed.

# Initial add (run once on fresh clone)
git subtree add --prefix=tmux/.tmux/plugins/tpm tpm master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-sensible tmux-sensible master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-yank tmux-yank master --squash
git subtree add --prefix=tmux/.tmux/plugins/vim-tmux-navigator vim-tmux-navigator master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-resurrect tmux-resurrect master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-continuum tmux-continuum master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-thumbs tmux-thumbs master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-floax tmux-floax main --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-fzf-url tmux-fzf-url master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-cpu tmux-cpu master --squash

# Update all tmux plugins to latest
git subtree pull --prefix=tmux/.tmux/plugins/tpm tpm master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-sensible tmux-sensible master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-yank tmux-yank master --squash
git subtree pull --prefix=tmux/.tmux/plugins/vim-tmux-navigator vim-tmux-navigator master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-resurrect tmux-resurrect master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-continuum tmux-continuum master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-thumbs tmux-thumbs master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-floax tmux-floax main --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-fzf-url tmux-fzf-url master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-cpu tmux-cpu master --squash
```

---

### 2) zsh / Oh My ZSH (8 subtrees)

```bash
cd $HOME/.stowed

# Add remotes (idempotent)
git remote add oh-my-zsh https://github.com/ohmyzsh/ohmyzsh
git remote add zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
git remote add zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
git remote add zsh-vi-mode https://github.com/jeffreytse/zsh-vi-mode
git remote add forgit https://github.com/wfxr/forgit
git remote add tmux-xpanes https://github.com/greymd/tmux-xpanes
git remote add last-working-dir-tmux https://github.com/badaniya/last-working-dir-tmux

# Add remotes (idempotent)
git remote add oh-my-zsh https://github.com/ohmyzsh/ohmyzsh
git remote add zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
git remote add zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
git remote add zsh-vi-mode https://github.com/jeffreytse/zsh-vi-mode
git remote add forgit https://github.com/wfxr/forgit
git remote add tmux-xpanes https://github.com/greymd/tmux-xpanes
git remote add last-working-dir-tmux https://github.com/badaniya/last-working-dir-tmux
git remote add zsh-syntax-highlighting-catppuccin https://github.com/catppuccin/zsh-syntax-highlighting

# Initial add (run once on fresh clone)
git subtree add --prefix=zsh/.oh-my-zsh oh-my-zsh master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting zsh-syntax-highlighting master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-autosuggestions zsh-autosuggestions master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-vi-mode zsh-vi-mode master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/forgit forgit HEAD --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/tmux-xpanes tmux-xpanes master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/last-working-dir-tmux last-working-dir-tmux master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/catppuccin zsh-syntax-highlighting-catppuccin main --squash

# Update all zsh plugins to latest
git subtree pull --prefix=zsh/.oh-my-zsh oh-my-zsh master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting zsh-syntax-highlighting master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-autosuggestions zsh-autosuggestions master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-vi-mode zsh-vi-mode master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/forgit forgit HEAD --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/tmux-xpanes tmux-xpanes master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/last-working-dir-tmux last-working-dir-tmux master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/catppuccin zsh-syntax-highlighting-catppuccin main --squash
```

---

### 3) nvim (kickstart.nvim based, NOT a subtree)

```bash
# nvim config is maintained directly in this repo at nvim/.config/nvim/
# It is based on kickstart.nvim but heavily customized.
# NO git subtree is used for nvim itself.

# To update kickstart.nvim upstream changes, manually merge from:
# https://github.com/nvim-lua/kickstart.nvim
```

---

### 4) vim Plugins (7 subtrees - legacy, consider migrating to nvim)

```bash
cd $HOME/.stowed

# Add remotes (idempotent)
git remote add ferret https://github.com/wincent/ferret.git
git remote add lightline.vim https://github.com/itchyny/lightline.vim
git remote add nerdtree https://github.com/preservim/nerdtree
git remote add nerdtree-git-plugin https://github.com/Xuyuanp/nerdtree-git-plugin
git remote add vim-fugitive https://github.com/tpope/vim-fugitive
git remote add vim-gitgutter https://github.com/airblade/vim-gitgutter
git remote add vim-go https://github.com/fatih/vim-go

# Initial add (run once on fresh clone)
git subtree add --prefix=vim/.vim/plugged/ferret ferret master --squash
git subtree add --prefix=vim/.vim/plugged/lightline.vim lightline.vim master --squash
git subtree add --prefix=vim/.vim/plugged/nerdtree nerdtree master --squash
git subtree add --prefix=vim/.vim/plugged/nerdtree-git-plugin nerdtree-git-plugin master --squash
git subtree add --prefix=vim/.vim/plugged/vim-fugitive vim-fugitive master --squash
git subtree add --prefix=vim/.vim/plugged/vim-gitgutter vim-gitgutter main --squash
git subtree add --prefix=vim/.vim/plugged/vim-go vim-go master --squash

# Update all vim plugins to latest
git subtree pull --prefix=vim/.vim/plugged/ferret ferret master --squash
git subtree pull --prefix=vim/.vim/plugged/lightline.vim lightline.vim master --squash
git subtree pull --prefix=vim/.vim/plugged/nerdtree nerdtree master --squash
git subtree pull --prefix=vim/.vim/plugged/nerdtree-git-plugin nerdtree-git-plugin master --squash
git subtree pull --prefix=vim/.vim/plugged/vim-fugitive vim-fugitive master --squash
git subtree pull --prefix=vim/.vim/plugged/vim-gitgutter vim-gitgutter main --squash
git subtree pull --prefix=vim/.vim/plugged/vim-go vim-go master --squash
```

---

### 5) fzf

```bash
cd $HOME/.stowed

# Add remote (idempotent)
git remote add fzf https://github.com/junegunn/fzf.git

# Initial add (run once on fresh clone)
git subtree add --prefix=fzf/.fzf fzf master --squash

# Update fzf to latest
git subtree pull --prefix=fzf/.fzf fzf master --squash
```

---

### 6) AI Agent Skills (No Longer a Subtree)

Skills for AI agents (opencode, goose, copilot, herdr, etc.) are managed via the
`npx skills` CLI instead of git subtrees.

```bash
# Install skills using the skills CLI (https://skills.sh/)
npx skills find <query>              # Search for skills
npx skills add <owner/repo@skill> -g -y  # Install a skill globally

# Example: Install all obra/superpowers skills
npx skills add obra/superpowers -g -y

# Check for skill updates
npx skills check
npx skills update
```

**Note**: The `agents/.agents/skills/` directory in this repo contains custom skills
that are symlinked via GNU Stow. Third-party skills from `npx skills` are installed
to `~/.agents/skills/` outside this repo.

---

### Branch Reference

| Remote | Branch Used | Notes |
|--------|-------------|-------|
| tpm | master | |
| tmux-sensible | master | |
| tmux-yank | master | |
| vim-tmux-navigator | master | |
| tmux-resurrect | master | |
| tmux-continuum | master | |
| tmux-thumbs | master | |
| tmux-floax | main | Uses `main` branch |
| tmux-fzf-url | master | |
| tmux-cpu | master | |
| oh-my-zsh | master | |
| zsh-syntax-highlighting | master | |
| zsh-autosuggestions | master | |
| zsh-vi-mode | master | |
| forgit | HEAD | Uses default branch (`HEAD`) |
| tmux-xpanes | master | |
| last-working-dir-tmux | master | |
| zsh-syntax-highlighting-catppuccin | main | Catppuccin theme for zsh-syntax-highlighting |
| ferret | master | |
| lightline.vim | master | |
| nerdtree | master | |
| nerdtree-git-plugin | master | |
| vim-fugitive | master | |
| vim-gitgutter | main | Uses `main` branch |
| vim-go | master | |
| fzf | master | |

---

### Quick Update All Script

```bash
#!/usr/bin/env bash
# Update all subtrees in one go
set -euo pipefail
cd "$HOME/.stowed"

echo "Updating tmux plugins..."
git subtree pull --prefix=tmux/.tmux/plugins/tpm tpm master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-sensible tmux-sensible master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-yank tmux-yank master --squash
git subtree pull --prefix=tmux/.tmux/plugins/vim-tmux-navigator vim-tmux-navigator master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-resurrect tmux-resurrect master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-continuum tmux-continuum master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-thumbs tmux-thumbs master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-floax tmux-floax main --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-fzf-url tmux-fzf-url master --squash
git subtree pull --prefix=tmux/.tmux/plugins/tmux-cpu tmux-cpu master --squash

echo "Updating zsh plugins..."
git subtree pull --prefix=zsh/.oh-my-zsh oh-my-zsh master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting zsh-syntax-highlighting master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-autosuggestions zsh-autosuggestions master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-vi-mode zsh-vi-mode master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/forgit forgit HEAD --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/tmux-xpanes tmux-xpanes master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/last-working-dir-tmux last-working-dir-tmux master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/catppuccin zsh-syntax-highlighting-catppuccin main --squash

echo "Updating vim plugins..."
git subtree pull --prefix=vim/.vim/plugged/ferret ferret master --squash
git subtree pull --prefix=vim/.vim/plugged/lightline.vim lightline.vim master --squash
git subtree pull --prefix=vim/.vim/plugged/nerdtree nerdtree master --squash
git subtree pull --prefix=vim/.vim/plugged/nerdtree-git-plugin nerdtree-git-plugin master --squash
git subtree pull --prefix=vim/.vim/plugged/vim-fugitive vim-fugitive master --squash
git subtree pull --prefix=vim/.vim/plugged/vim-gitgutter vim-gitgutter main --squash
git subtree pull --prefix=vim/.vim/plugged/vim-go vim-go master --squash

echo "Updating fzf..."
git subtree pull --prefix=fzf/.fzf fzf master --squash

echo "All subtrees updated. Commit and push:"
echo "  git add -A && git commit -m 'chore: update all subtrees' && git push"
```

---

### Last Updated

- **Date**: 2026-11-15
- **Commit**: `422609247` (all subtrees refreshed + catppuccin zsh theme added)
- **Note**: All subtrees now have remotes configured for repeatable `git subtree pull` updates.