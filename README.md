# .stowed
This repository is used to store all dot-config files for various shells and editors.  This repository can be cloned to a new linux machine which can be setup quickly with GNU `stow`. This will bring back all custom shell and editor configurations or easily sync custom configuration between linux machines.

[How Nested Git Repositories Are Configured - For Reference ONLY](nested_git_repos.md):  A reference on how this .stowed repository was created with the various nested git repositories for the shell and editor plugins.

**Stowed Terminal Tools:**

- ghostty
- tmux
- fzf
- zoxide
- bat
- delta
- starship

**Stowed Shells:**

- bash
- zsh

**Stowed Editors:**

- nvim
- vim
- emacs

## How To Use GNU Stow

### 1) Install GNU Stow

```bash
# Install Stow
sudo apt install -y stow
```

### 2) Clone This Repo on a New Linux Host

```bash
git clone https://github.com/badaniya/.stowed $HOME/.stowed
```

### 3) Run Stow Command to Establish Symlinks to the Repository

```bash
# Create Symlinks to Repo
stow -d $HOME/.stowed stow ghostty tmux fzf bat delta starship bash zsh nvim vim emacs

# To Force Symlink Creation (NOTE: May miss some hidden files or symlinks)
stow -d $HOME/.stowed --adopt ghostty stow tmux fzf bat delta starship bash zsh nvim vim emacs
cd $HOME/.stowed
git reset --hard HEAD

# Sure-file Way to Ensure Stow Symlink Creation (NOTE: Ensure the GNU Stow succeeds before quitting the shell) 
rm -rf $HOME/.config/ghostty; rm -rf $HOME/.bash*; rm -rf $HOME/.zsh*; rm -rf $HOME/.oh-my-zsh; rm -rf $HOME/.config/nvim; rm -rf $HOME/.vim*; rm -rf $HOME/.emacs*; stow -d $HOME/.stowed stow ghostty tmux fzf bat delta starship bash zsh nvim vim emacs
```

## Follow-up Package Installation for Shell/Editor Tools

### 0) Ghostty

```bash
# ghostty: Ubuntu debian version
wget https://github.com/mkasberg/ghostty-ubuntu/releases/download/1.0.1-0-ppa1/ghostty_1.0.1-0.ppa1_amd64_24.04.deb
sudo dpgk -i ghostty_1.0.1-0.ppa1_amd64_24.04.deb
```

### 1) Tmux

```bash
# tmux: Ubuntu package version
sudo apt install -y tmux
```

### 2) Zsh

```bash
# zsh: Ubuntu package version
sudo apt install -y zsh
```

### 3) Fzf

```bash
# fzf: Ubuntu package version
sudo apt install -y fzf
```

### 4) Zoxide

```bash
# zoxide: Shell script installer
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
```

### 5) Bat

```bash
# bat: Ubuntu package version
sudo apt install bat
mkdir -p ~/.local/bin
ln -s /usr/bin/batcat ~/.local/bin/bat
bat cache --build
```

### 6) Delta

```bash
# delta: git diff colorized
wget https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_amd64.deb
sudo dpkg -i git-delta_0.18.2_amd64.deb
git config --global include.path '~/.config/delta/delta.gitconfig'
```

### 7) Starship

```bash
# starship: Shell script installer
curl -sS https://starship.rs/install.sh | sh
```

### 6) Neovim

```bash
# neovim: Latest version
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz

# ripgrep: For NeoVIM search
sudo apt install -y ripgrep

# nerdfont: Terminal fonts for nvim theme
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
unzip -od ~/.local/share/fonts/ JetBrainsMono.zip
fc-cache -fv
```

### 6.1) Neovim Plugin Dependencies

#### Database UI Plugin

```bash
# DB UI - postgres/mysql (vim-dadbod and vim-dadbod-ui)
sudo apt install -y postgresql-client
sudo apt install -y mariadb-client 
```

### 7) Vim

```bash
sudo apt install -y vim
```

### 8) Emacs

```bash
sudo apt-add-repository -y ppa:kelleyk/emacs
sudo apt update -y
sudo apt install -y emacs28
```

## Linux Development Environment Setup

### 1) Golang

```bash
# golang:
golang_version="1.22.7"
wget https://go.dev/dl/go"$golang_version".linux-amd64.tar.gz
sudo tar -xvf go"$golang_version".linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo mv go /usr/local

# gopls:
go install golang.org/x/tools/gopls@latest

# dlv:
go install github.com/go-delve/delve/cmd/dlv@latest

# golangci-lint:
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sudo sh -s -- -b /usr/bin v1.55.2

# gosec:
cd ~/.go
curl -sSfL https://raw.githubusercontent.com/securego/gosec/master/install.sh | sh -s v2.18.1

# gotestsum:
go install gotest.tools/gotestsum@latest
```

## How to Use These Stowed Shell/Editor Tools

```bash
# 1) Start a new tmux session
tmux [new -s <session-name> [-c <start-directory>]]

# 2) Start nvim from within tmux to maintain session persistence across remote shell logins
nvim
```

## General Tmux Session Commands

```bash
# 1) List existing tmux sessions
tmux ls

# 2) Detach from a tmux session
tmux detach

# 3) Attach to a tmux session
tmux attach -t <# | session-name>

# 4) Delete a tmux session
tmux kill-session -t <# | session-name>

# 5) Delete all tmux sessions
tmux kill-server
```

## Tmux Key Bindings

```text
# General Tmux Bindings (<C> is the Ctrl key)
<C-b> $ : Rename the tmux session name
<C-b> c : Creates a new tmux window
<C-b> " : Creates a new tmux pane horizontally split below
<C-b> % : Creates a new tmux pane vertically split on the right
<C-b> x : Exits current tmux pane or window (user prompted)
<C-b> q : Displays tmux pane numbers
<C-b> # : Switch to the tmux window number

# Tmux Sessions Switching
<C-b> s : Displays a tmux sessions menu to switch between tmux sessions

# Tmux Pane Switching
<C-h> : Move to the pane on the left
<C-j> : Move to the pane below
<C-k> : Move to the pane above
<C-l> : Move to the pane on the right
<C-b> q # : Selects the pane number to switch to
<C-b> p : Toggles a floating pane

# Tmux Pane Zoom-in/Zoom-out
<C-b> z : Toggles the current pane to zoom-in or zoom-out

# Tmux Pan Resizing (keyboard)
<C-b> <C-arrow-keys> : Fine grained resizing
<C-b> <M-arrow-keys> : Coarse grained resizing

# Newer Tmux 3.2 Copy/Paste (mouse)
<left-mouse-click> : copy
<middle-mouse-click> : paste

# Older Tmux 3.0a Copy/Paste (mouse)
<C-S-left-mouse-click> : copy
<C-S-middle-mouse-click> : paste 

# Tmux Copy/Paste vi-copy-mode (keyboard)
<C-b> [ : Enters copy-mode
<space> : Starts the selection (use vi motions to expand the selection)
<enter> : Stores the selection
<C-b> ] : Pastes the selection
```

## Nvim Key Bindings

```text
# General Nvim Bindings
<space> : Main leader key for all menus
<\> : Toggle NeoTree - Directory Browser
<*> : Bring up search for the highlighted text object
<q-/> : Bring up search history
<q-:> : Bring up command history
<C-v> : Block-Visual editing mode (<C-q> for WSL2)

# Nvim Search Bindings
<C-r-w> : Paste highlighted text object in search mode

# Nvim Window Switching (<C> is the Ctrl key)
<C-h> : Move to the window on the left
<C-j> : Move to the window below
<C-k> : Move to the window above
<C-l> : Move to the window on the right

# Nvim Tab Switching (<M> is the Alt key)
<M-#> : Switch to the file tab #
<M-,> : Switch to the file tab on the left
<M-.> : Switch to the file tab on the right
<M-<> : Move the current file tab position to the left
<M->> : Move the current file tab position to the right 
<M-c> : Close out the current file tab
<M-p> : Toggle pinning the current file tab

# Nvim Code Navigation
<C-]> | <C-left-mouse-click>: Go to Definition
<C-t> | <C-right-mouse-click> : Pop back up the stack
<leader> ld : LSP Definitions
<leader> lr : LSP References
<leader> li : LSP Implementations

# Nvim Telescope
<leader> sg : ripgrep search in project workspace
<C-q> : Add telescope search results to the quickfix list

# Nvim Debug
<F2> : Step Into
<F3> : Step Over
<F4> : Step Out
<F5> : Start/Continue
<F6> : Debug Nearest Test
<F7> : Restart Last Debug Session
<F8> : Toggle Breakpoint
<F9> : Toggle Conditional Breakpoint
<F12> : Stop Debugger
```
