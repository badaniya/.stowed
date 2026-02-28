export EDITOR=nvim
#export LC_ALL="en_US.UTF-8"
#export LC_ALL="C"
export VAGRANT_HOME=$HOME/.vagrant.d

## Golang Environment Settings ##
export GOBASEPATH=$HOME/.go
export GO111MODULE=on
export GOMODCACHE=$GOBASEPATH/pkg/mod
export GOROOT="/usr/local/go"
export GOPATH=$GOBASEPATH

if [[ ! "$PATH" =~ $GOROOT/bin ]]; then
    export PATH=$GOROOT/bin:$PATH
fi

if [[ ! "$PATH" =~ $GOBASEPATH/bin ]]; then
    export PATH=$GOBASEPATH/bin:$PATH
fi

export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin:/opt/nvim-linux-x86_64/bin:$HOME/.opencode/bin

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
