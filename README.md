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

**Stowed Optional Terminal Tools:**

- tmuxinator
- gitui
- lazygit
- imagemagick
- mermaid-cli
- kubecolor (kubectl)

**Stowed Optional AI Terminal Tools:**

- copilot-cli
- opencode
- pi
- goose
- mcphub (NeoVIM MCP servers hub)
- vectorcode (vector DB)
- agents (centralized skills for AI tools)

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

# Sure-fire way to ensure stow symlink creation (NOTE: Ensure the GNU Stow succeeds before quitting the shell) 
rm -rf $HOME/.config/ghostty; rm -rf $HOME/.bash*; rm -rf $HOME/.zsh*; rm -rf $HOME/.oh-my-zsh; rm -rf $HOME/.config/nvim; rm -rf $HOME/.vim*; rm -rf $HOME/.emacs*; stow -d $HOME/.stowed stow ghostty tmux fzf bat delta starship bash zsh nvim vim emacs
```

### 4) Run Stow Command to Establish Symlinks to the Repository for Optional Terminal Tools

```bash
# Sure-fire way to ensure stow symlink creation (NOTE: Ensure the GNU Stow succeeds before quitting the shell) 
rm -rf $HOME/.config/tmuxinator; rm -rf $HOME/.config/gitui; rm -rf $HOME/.config/lazygit; stow -d $HOME/.stowed tmuxinator gitui lazygit
```

### 5) Run Stow Command to Establish Symlinks to the Repository for Optional AI Terminal Tools

```bash
# Sure-fire way to ensure stow symlink creation (NOTE: Ensure the GNU Stow succeeds before quitting the shell) 
rm -rf $HOME/.npmrc; rm -rf $HOME/.config/.copilot; rm -rf $HOME/.config/opencode; rm -rf $HOME/.pi; rm -rf $HOME/.config/goose; rm -rf $HOME/.config/mcphub; rm -rf $HOME/.config/vectorcode; rm -rf $HOME/.agents; stow -d $HOME/.stowed npm copilot opencode pi goose mcphub vectorcode agents
```

## Installing Stowed Terminal Tools

### 0) Ghostty - A fast efficient terminal with GPU acceleration and Kitty image support

```bash
# ghostty: Ubuntu debian version - official w/systemd support
sudo snap install ghostty --classic

# ghostty: Ubuntu debian version - unofficial
sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"

# NOTE: For WSL2 environment, stick with ghostty 1.1.3 because of CPU utilization for ghostty 1.2+ is high (in WSL2 only)
wget https://github.com/mkasberg/ghostty-ubuntu/releases/download/1.1.3-0-ppa2/ghostty_1.1.3-0.ppa2_amd64_24.04.deb
sudo dpkg -i ghostty_1.1.3-0.ppa2_amd64_24.04.deb

# NOTE: Copy Ghostty's terminfo to a remote machine if tmux fails with: `missing or unsuitable terminal: xterm-ghostty`
# The following one-liner will export the terminfo entry from your host and import it on the remote machine:
# Reference: https://ghostty.org/docs/help/terminfo#copy-ghostty's-terminfo-to-a-remote-machine 
infocmp -x xterm-ghostty | ssh <YOUR-REMOTE-SERVER-IP> -- tic -x -
```

### 1) Tmux - A terminal multiplexer to maintain terminal sessions and split-pane layouts

```bash
# tmux: Ubuntu package version
sudo apt install -y tmux
```

### 2) Zsh - A powerful bash-like shell with command completion and syntax highlighting

```bash
# zsh: Ubuntu package version
sudo apt install -y zsh
```

### 3) Fzf - A fuzzy finder that integrates with various shells and editors

```bash
# fzf: Shell script installer (NOTE: Ensure GNU Stow fzf is done before running the installation script)
~/.fzf/install
```

### 4) Zoxide - A quick way to change directories to your most frequently used paths

```bash
# zoxide: Shell script installer
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
```

### 5) Bat - A visually pleasing and themed `cat`

```bash
# bat: Ubuntu package version
sudo apt install bat
mkdir -p ~/.local/bin
ln -s /usr/bin/batcat ~/.local/bin/bat
bat cache --build
```

### 6) Delta - A visually pleasing and themed diff tool (using `bat`)

```bash
# delta: git diff colorized
wget https://github.com/dandavison/delta/releases/download/0.18.2/git-delta_0.18.2_amd64.deb
sudo dpkg -i git-delta_0.18.2_amd64.deb
git config --global include.path '~/.config/delta/delta.gitconfig'
```

### 7) Starship - A tool to help customize your shell prompt

```bash
# starship: Shell script installer
curl -sS https://starship.rs/install.sh | sh
```

### 8) Neovim - A `vim` editor with outstanding plug-in support to make a fully customizable programming IDE 

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

### 8.1) Neovim Plugin Dependencies

#### Database UI Plugin

```bash
# DB UI - postgres/mysql (vim-dadbod and vim-dadbod-ui)
sudo apt install -y postgresql-client
sudo apt install -y mariadb-client 
```

#### CopilotChat, CodeCompanion, Avante Plugins - AI chat for github copilot and others which uses nodejs

```bash
# Nix dependency
nix-env -iA nixpkgs.nodejs_22

# Global install of mcp-hub for agent based AI tools
npm install -g mcp-hub@latest

# Global install of copilot-cli
npm install -g @github/copilot
```

### 9) Vim - A ubiquitous editor

```bash
sudo apt install -y vim
```

### 10) Emacs - GNU editor

```bash
sudo apt-add-repository -y ppa:kelleyk/emacs
sudo apt update -y
sudo apt install -y emacs28
```

## Installing Optional Stowed Terminal Tools

### 1) Nix Package Manager - A package manager with a massive amount of open-source installation images

```bash
# Multi-User Nix Package Manager Installer
sh <(curl -L https://nixos.org/nix/install) --daemon
```

### 3) Tmuxinator - A tmux session layout creator

```bash
# Nix dependency
nix-env -iA nixpkgs.tmuxinator
```

### 4) Gitui - Terminal Git TUI (Rust based)

```bash
# Nix dependency
nix-env -iA nixpkgs.gitui
```

### 5) Lazygit - Another Terminal Git TUI

```bash
# Nix dependency
nix-env -iA nixpkgs.lazygit
```

### 6) Image and Diagram Markdown Support in Neovim

```bash
# Nix dependency
nix-env -iA nixpkgs.imagemagick
nix-env -iA nixpkgs.mermaid-cli
```

### 7) Kulala format conversion - Openapi to http

```bash
npm install -g @mistweaverco/kulala-fmt
# or
# Nix dependency
nix-env -iA nixpkgs.kulala-fmt
```

## Installing Optional Stowed AI Terminal Tools

### 1) NPM - Node package manager for AI tools

```bash
# Nix dependency
nix-env -iA nixpkgs.nodejs_22
```

### 2) Copilot-cli - GitHub Copilot for the terminal

```bash
npm install -g @github/copilot
```

### 3) Opencode - An open source AI coding agent for the terminal

```bash
curl -fsSL https://opencode.ai/install | bash
```

### 4) Pi - A fully customizable AI coding agent for the terminal

```bash
npm install -g @mariozechner/pi-coding-agent
pi install npm:pi-extmgr
pi install npm:@ujjwalgrover/pi-catppuccin
pi install npm:@marckrenn/pi-sub-share
pi install npm:@marckrenn/pi-sub-core
pi install npm:@marckrenn/pi-sub-bar
```

### 5) Goose - An AI coding assistant for the terminal

```bash
curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash
```

### 6) Vectorcode - A source code indexed vector DB for AI MCP use 

```bash
uv tool install "vectorcode<1.0.0"
# or
# Nix dependency
nix-env -iA nixpkgs.vectorcode
```

### 7) Agents - A centralized skills area for all AI tools

```bash
# Sure-fire way to ensure stow symlink creation
rm -rf $HOME/.agents; stow -d $HOME/.stowed agents
```

## Linux Development Environment Setup

### 1) Golang

```bash
# golang:
golang_version="1.25.3"
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
<C-y>   : In copy-mode, pastes the selection into a tmux `search up/down` command line
<C-b> ] : Pastes the selection outside of copy-mode
```

## Tmux Plugin Key Bindings

```text
# tmux-fzf-url - Fzf URL Links Launcher
<C-b> u : Use the fuzzy finder to select from a list of URL links to launch 

# tmux-thumbs - Activate a quick copy mode to make selections of text from the tmux pane
<C-b> space : Quick copy mode to capture file paths, UUIDs, IP addresses...
```

## Nvim Key Bindings

```text
# General Nvim Bindings
<space> : Main leader key for all menus
<\> : Toggle NeoTree - Directory Browser
<#> : Upwards search for the highlighted text object
<*> : Downwards search for the highlighted text object
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
