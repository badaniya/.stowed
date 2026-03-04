# Source Common Bash Functions
if [[ "$SHELL" =~ bash && -f $HOME/.bash_functions.sh ]]; then
    source $HOME/.bash_functions.sh
elif [[ "$SHELL" =~ zsh && -f $HOME/.zsh_functions.zsh ]]; then
    source $HOME/.zsh_functions.zsh
fi

# Source Other Aliases
if [[ -f $HOME/.private_bash_aliases ]]; then
    source $HOME/.private_bash_aliases
fi

# System Aliases
alias freebuffcache="sudo bash -c 'echo 3 > /proc/sys/vm/drop_caches'"
alias runmemlimit="systemd-run --user --scope --property=MemoryHigh=1G "
alias iosched="sudo bash -c 'echo bfq > /sys/block/sda/queue/scheduler'; cat /sys/block/sda/queue/scheduler"

# Linux Aliases
alias fzfbat="fzf --preview 'bat --color=always --style=numbers --line-range=:500 {}'"
alias l="pls -d std"
alias xpanes='xpanes -t -B "tmux select-pane -t \${TMUX_PANE} -T \"ARG:{} PID:$$\""'

# Go Aliases
alias gomodtidy="find . -type f ! -path '*/pkg/*' -name go.mod -execdir pwd \; -execdir go mod tidy -go=1.20 \;"
alias gomodtidycompat="find . -type f ! -path '*/pkg/*' -name go.mod -execdir pwd \; -execdir go mod tidy -compat=1.19 \;"
alias gowork="go_work"
alias goinstalldlv="go install github.com/go-delve/delve/cmd/dlv@latest"
alias goinstallgopls="go install golang.org/x/tools/gopls@latest"
alias goinstallgodef="go install github.com/rogpeppe/godef@latest"

# Kubernetes Aliases
alias k3sctl="k3s kubectl"
which kubecolor >/dev/null && alias kubectl="kubecolor"

# Diff-Review Aliases
alias dr="$HOME/diff-review/diff-review"
alias vr="$HOME/diff-review/view-review"
alias vrt="$HOME/diff-review/view-review-tabs --palette dstd --keybindings $HOME/.config/diff-review/vim.json"

# Terminal/Expect Aliases
alias gterm="terminal_launcher gnome-terminal"
alias mterm="terminal_launcher mate-terminal"
alias messh="multiple_expect_ssh"
alias mescp="multiple_expect_scp"
alias mer2lscp="multiple_expect_remote_to_local_scp"
alias metelnet="multiple_expect_telnet"
alias mefwdl="multiple_expect_firmwaredownload"
