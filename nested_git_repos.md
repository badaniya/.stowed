[Go Back to the Main README](README.md)

## How Nested Git Repositories Are Configured - For Reference ONLY

### General Remote and Subtree Maintenance

```bash
# GIT remote - List existing remote additions with subtree prefixes
git remote -v

# GIT subtree - Update existing changes subtrees
git subtree pull --prefix=<prefix path> <remote name> <branch name> --squash
git push origin main
```

### 1) tmux

```bash
# TPM - TMUX Plugin Manager
cd $HOME/.stowed
git remote add tpm https://github.com/tmux-plugins/tpm
git remote add tmux-sensible https://github.com/tmux-plugins/tmux-sensible
git remote add tmux-yank https://github.com/tmux-plugins/tmux-yank
git remote add vim-tmux-navigator https://github.com/christoomey/vim-tmux-navigator
git remote add tmux-resurrect https://github.com/tmux-plugins/tmux-resurrect
git remote add tmux-continuum https://github.com/tmux-plugins/tmux-continuum
git remote add tmux-thumbs https://github.com/fcsonline/tmux-thumbs
git remote add tmux-floax https://github.com/omerxx/tmux-floax
git remote add tmux-fzf-url https://github.com/wfxr/tmux-fzf-url
git remote add catppuccin https://github.com/catppuccin/tmux
git remote add tmux-cpu https://github.com/tmux-plugins/tmux-cpu
git subtree add --prefix=tmux/.tmux/plugins/tpm tpm master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-sensible tmux-sensible master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-yank tmux-yank master --squash
git subtree add --prefix=tmux/.tmux/plugins/vim-tmux-navigator vim-tmux-navigator master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-resurrect tmux-resurrect master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-continuum tmux-continuum master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-thumbs tmux-thumbs master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-floax tmux-floax main --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-fzf-url tmux-fzf-url master --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux catppuccin main --squash
git subtree add --prefix=tmux/.tmux/plugins/tmux-cpu tmux-cpu master --squash
```

### 2) zsh

```bash
# Oh My ZSH Repo
cd $HOME/.stowed
git remote add oh-my-zsh https://github.com/ohmyzsh/ohmyzsh
git subtree add --prefix=zsh/.oh-my-zsh oh-my-zsh master --squash

# How to Pull in Oh My ZSH Updates
git subtree pull --prefix=zsh/.oh-my-zsh oh-my-zsh master --squash

# ZSH Plugins
git remote add zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
git remote add zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions
git remote add zsh-syntax-highlighting-catppuccin https://github.com/catppuccin/zsh-syntax-highlighting
git remote add last-working-dir-tmux https://github.com/badaniya/last-working-dir-tmux
git remote add zsh-vi-mode https://github.com/jeffreytse/zsh-vi-mode
git remote add forgit https://github.com/wfxr/forgit
git remote add tmux-xpanes https://github.com/greymd/tmux-xpanes
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting zsh-syntax-highlighting master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-autosuggestions zsh-autosuggestions master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/catppuccin zsh-syntax-highlighting-catppuccin main --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/last-working-dir-tmux last-working-dir-tmux master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-vi-mode zsh-vi-mode master --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/forgit forgit main --squash
git subtree add --prefix=zsh/.oh-my-zsh/custom/plugins/tmux-xpanes tmux-xpanes master --squash

# How to Pull in Oh My ZSH Plugin Updates
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting zsh-syntax-highlighting master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-autosuggestions zsh-autosuggestions master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/catppuccin zsh-syntax-highlighting-catppuccin main --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/last-working-dir-tmux last-working-dir-tmux master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/zsh-vi-mode zsh-vi-mode master --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/forgit forgit main --squash
git subtree pull --prefix=zsh/.oh-my-zsh/custom/plugins/tmux-xpanes tmux-xpanes master --squash
```

### 3) nvim

```bash
# NVIM Repo
cd $HOME/.stowed
git remote add nvim https://github.com/badaniya/nvim
git subtree add --prefix=nvim/.config/nvim nvim master
```

### 4) vim

```bash
# VIM Repo
cd $HOME/.stowed
git remote add ferret https://github.com/wincent/ferret.git
git remote add lightline.vim https://github.com/itchyny/lightline.vim
git remote add nerdtree https://github.com/preservim/nerdtree
git remote add nerdtree-git-plugin https://github.com/Xuyuanp/nerdtree-git-plugin
git remote add vim-fugitive https://github.com/tpope/vim-fugitive
git remote add vim-gitgutter https://github.com/airblade/vim-gitgutter
git remote add vim-go https://github.com/fatih/vim-go
git subtree add --prefix=vim/.vim/plugged/ferret ferret master --squash
git subtree add --prefix=vim/.vim/plugged/lightline.vim lightline.vim master --squash
git subtree add --prefix=vim/.vim/plugged/nerdtree nerdtree master --squash
git subtree add --prefix=vim/.vim/plugged/nerdtree-git-plugin nerdtree-git-plugin master --squash
git subtree add --prefix=vim/.vim/plugged/vim-fugitive vim-fugitive master --squash
git subtree add --prefix=vim/.vim/plugged/vim-go vim-go master --squash
git subtree add --prefix=vim/.vim/plugged/vim-gitgutter vim-gitgutter main --squash
```

### 5) fzf

```bash
cd $HOME/.stowed
git remote add fzf https://github.com/junegunn/fzf.git
git subtree add --prefix=fzf/.fzf fzf master --squash
```

### 6) AI Agent Skills (No Longer a Subtree)

Skills for AI agents (opencode, goose, copilot) are now managed via the `npx skills` CLI
instead of git subtrees. Skills are installed to `~/.agents/skills/` and symlinked to
each agent's config directory.

```bash
# Install skills using the skills CLI (https://skills.sh/)
npx skills find <query>              # Search for skills
npx skills add <owner/repo@skill> -g -y  # Install a skill globally

# Example: Install all obra/superpowers skills
npx skills add obra/superpowers@brainstorming -g -y
npx skills add obra/superpowers@systematic-debugging -g -y
npx skills add obra/superpowers@test-driven-development -g -y
npx skills add obra/superpowers@writing-plans -g -y
npx skills add obra/superpowers@executing-plans -g -y
npx skills add obra/superpowers@subagent-driven-development -g -y

# Check for skill updates
npx skills check
npx skills update
```

**Note**: The `agents/.agents/skills/` directory in this repo contains custom skills
that are symlinked via GNU Stow. Third-party skills from `npx skills` are installed
to `~/.agents/skills/` outside this repo.
