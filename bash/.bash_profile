export EDITOR=nvim
#export LC_ALL="en_US.UTF-8"
#export LC_ALL="C"
export VAGRANT_HOME=$HOME/.vagrant.d

# PATH helper
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

## WSL Interop PATH Trim ##
# WSL appends the entire Windows PATH, so $PATH carried ~39 directories under /mnt/c on
# the drvfs mount, at ~6-13 ms each to stat. Every *failed* lookup walks all of them: a
# single typo cost ~640 ms before "command not found". Keep only the directories that
# hold the interop tools used from here (explorer.exe, clip.exe, cmd.exe, wsl.exe,
# powershell.exe); anything else on the Windows side still works by full path.
# Also drop duplicate entries, which mise/conda/repeated sourcing pile up.
# Mirrors the block at the top of zsh/.zshrc, and runs in bash and in zsh (which
# sources this file), so it has to stay portable.
_wsl_trim_path() {
    local kept="" seen=":" dir oldifs globoff=""
    if [ -n "${ZSH_VERSION:-}" ]; then
        set -- ${(s.:.)PATH}
    else
        oldifs=$IFS
        IFS=:
        case $- in
            *f*) ;;                      # noglob already on, do not switch it off
            *) set -f; globoff=1 ;;
        esac
        set -- $PATH
        IFS=$oldifs
        [ -n "$globoff" ] && set +f
    fi
    for dir in "$@"; do
        case $dir in
            /mnt/*) continue ;;
        esac
        case $seen in
            *":$dir:"*) continue ;;
        esac
        kept="${kept:+$kept:}$dir"
        seen="$seen$dir:"
    done
    PATH="$kept:/mnt/c/Windows:/mnt/c/Windows/system32:/mnt/c/Windows/System32/WindowsPowerShell/v1.0"
}
if [ -d /mnt/c/Windows ]; then
    _wsl_trim_path
    # A parent shell may export mise's snapshot of the untrimmed PATH, and
    # `mise activate` rebuilds $PATH from it, undoing the trim.
    unset __MISE_ORIG_PATH
fi
unset -f _wsl_trim_path
export PATH

## Golang Environment Settings ##
export GOBASEPATH=$HOME/.go
export GO111MODULE=on
export GOMODCACHE=$GOBASEPATH/pkg/mod
export GOROOT="/usr/local/go"
export GOPATH=$GOBASEPATH

path_prepend "$GOROOT/bin"
path_prepend "$GOBASEPATH/bin"

export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin:/opt/nvim-linux-x86_64/bin:$HOME/.opencode/bin

## Mise Shims ##
# Login/non-interactive shells do not run the activation hook; shims resolve the
# right tool version per directory and keep gh/tmux/fzf available without nix.
path_prepend "$HOME/.local/share/mise/shims"

## Docker Environment Settings ##
export DOCKER_BUILDKIT=1

## Kubectl Environment Settings ##
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export KUBECOLOR_CONFIG=~/.stowed/kubecolor/catppuccin-mocha.yaml

## Other Environment Settings ##
if [[ -f "$HOME/.private_bash_profile" ]]; then
    source "$HOME/.private_bash_profile"
fi

## Rust Cargo Environment Settings ##
if [[ -f $HOME/.cargo/enf ]]; then
    source "$HOME/.cargo/env"
fi

# Final PATH deduplication (after all PATH modifications)
path_dedup() {
    local IFS=:
    local kept="" seen="" dir
    for dir in $PATH; do
        case $seen in
            *":$dir:"*) continue ;;
        esac
        kept="${kept:+$kept:}$dir"
        seen="$seen$dir:"
    done
    PATH="$kept"
}
path_dedup
unset -f path_dedup
