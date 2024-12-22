# last-working-dir-tmux
Zsh plugin to load last working dir within a tmux session


Keeps track of the last used working directory globally and per tmux session and automatically jumps into it
for new shells, unless:

- The plugin is already loaded.
- The current `$PWD` is not `$HOME`.

Also adds `lwd` function to jump to the last working directory.
