# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="bullet-train"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "bira" "agnoster" "bullet-train" )

# BULLET-TRAIN Theme Settings
#BULLETTRAIN_DIR_EXTENDED=2
#BULLETTRAIN_TIME_12HR=true

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-vi-mode
    last-working-dir-tmux
    urltools
    tmux-xpanes
)

# Syntax highlighting plugin support
[[ -f $ZSH/custom/plugins/zsh-syntax-highlighting/catppuccin/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh ]] && source $ZSH/custom/plugins/zsh-syntax-highlighting/catppuccin/themes/catppuccin_mocha-zsh-syntax-highlighting.zsh

# Main oh-my-zsh script
[[ -f $ZSH/oh-my-zsh.sh ]] && source $ZSH/oh-my-zsh.sh

# User configuration
export ZVM_VI_EDITOR=nvim

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# ZSH Setup
export SHELL=`which zsh`
#export TERM=xterm-256color # Do not override tmux-256color if set (tmux-256color is needed for nvim snacks.image to render images properly)
export LS_COLORS='bd=0;38;2;116;199;236;48;2;49;50;68:pi=0;38;2;17;17;27;48;2;137;180;250:ln=0;38;2;245;194;231:fi=0:sg=0:di=0;38;2;137;180;250:su=0:or=0;38;2;17;17;27;48;2;243;139;168:so=0;38;2;17;17;27;48;2;245;194;231:ow=0:ca=0:do=0;38;2;17;17;27;48;2;245;194;231:mh=0:ex=1;38;2;243;139;168:tw=0:mi=0;38;2;17;17;27;48;2;243;139;168:*~=0;38;2;88;91;112:cd=0;38;2;245;194;231;48;2;49;50;68:rs=0:no=0:st=0:*.p=0;38;2;166;227;161:*.a=1;38;2;243;139;168:*.o=0;38;2;88;91;112:*.m=0;38;2;166;227;161:*.d=0;38;2;166;227;161:*.z=4;38;2;116;199;236:*.c=0;38;2;166;227;161:*.t=0;38;2;166;227;161:*.r=0;38;2;166;227;161:*.h=0;38;2;166;227;161:*.xz=4;38;2;116;199;236:*.vb=0;38;2;166;227;161:*.rm=0;38;2;242;205;205:*.lo=0;38;2;88;91;112:*.el=0;38;2;166;227;161:*.jl=0;38;2;166;227;161:*.ui=0;38;2;249;226;175:*.sh=0;38;2;166;227;161:*.ex=0;38;2;166;227;161:*.bz=4;38;2;116;199;236:*.py=0;38;2;166;227;161:*.hi=0;38;2;88;91;112:*.di=0;38;2;166;227;161:*.gz=4;38;2;116;199;236:*.so=1;38;2;243;139;168:*.nb=0;38;2;166;227;161:*.hs=0;38;2;166;227;161:*.pm=0;38;2;166;227;161:*.as=0;38;2;166;227;161:*.md=0;38;2;249;226;175:*.go=0;38;2;166;227;161:*.pp=0;38;2;166;227;161:*.kt=0;38;2;166;227;161:*css=0;38;2;166;227;161:*.ml=0;38;2;166;227;161:*.bc=0;38;2;88;91;112:*.hh=0;38;2;166;227;161:*.wv=0;38;2;242;205;205:*.rb=0;38;2;166;227;161:*.mn=0;38;2;166;227;161:*.rs=0;38;2;166;227;161:*.cp=0;38;2;166;227;161:*.pl=0;38;2;166;227;161:*.ps=0;38;2;243;139;168:*.cr=0;38;2;166;227;161:*.ts=0;38;2;166;227;161:*.fs=0;38;2;166;227;161:*.ko=1;38;2;243;139;168:*.gv=0;38;2;166;227;161:*.la=0;38;2;88;91;112:*.cc=0;38;2;166;227;161:*.ll=0;38;2;166;227;161:*.td=0;38;2;166;227;161:*.cs=0;38;2;166;227;161:*.js=0;38;2;166;227;161:*.7z=4;38;2;116;199;236:*.wmv=0;38;2;242;205;205:*.rar=4;38;2;116;199;236:*.aif=0;38;2;242;205;205:*.kex=0;38;2;243;139;168:*.sty=0;38;2;88;91;112:*.svg=0;38;2;242;205;205:*.sxi=0;38;2;243;139;168:*.com=1;38;2;243;139;168:*.sql=0;38;2;166;227;161:*.aux=0;38;2;88;91;112:*.tml=0;38;2;249;226;175:*.c++=0;38;2;166;227;161:*.apk=4;38;2;116;199;236:*.ppm=0;38;2;242;205;205:*.kts=0;38;2;166;227;161:*.pgm=0;38;2;242;205;205:*.ps1=0;38;2;166;227;161:*.bbl=0;38;2;88;91;112:*.jpg=0;38;2;242;205;205:*.tgz=4;38;2;116;199;236:*.pps=0;38;2;243;139;168:*.ico=0;38;2;242;205;205:*.nix=0;38;2;249;226;175:*.ltx=0;38;2;166;227;161:*hgrc=0;38;2;148;226;213:*.csv=0;38;2;249;226;175:*.dmg=4;38;2;116;199;236:*.mkv=0;38;2;242;205;205:*.ics=0;38;2;243;139;168:*.zip=4;38;2;116;199;236:*.yml=0;38;2;249;226;175:*.xml=0;38;2;249;226;175:*.bst=0;38;2;249;226;175:*.vim=0;38;2;166;227;161:*TODO=1:*.xmp=0;38;2;249;226;175:*.fsx=0;38;2;166;227;161:*.pyo=0;38;2;88;91;112:*.mid=0;38;2;242;205;205:*.mp4=0;38;2;242;205;205:*.mov=0;38;2;242;205;205:*.jar=4;38;2;116;199;236:*.wma=0;38;2;242;205;205:*.pbm=0;38;2;242;205;205:*.bat=1;38;2;243;139;168:*.img=4;38;2;116;199;236:*.fon=0;38;2;242;205;205:*.pdf=0;38;2;243;139;168:*.htm=0;38;2;249;226;175:*.m4a=0;38;2;242;205;205:*.otf=0;38;2;242;205;205:*.asa=0;38;2;166;227;161:*.ods=0;38;2;243;139;168:*.bz2=4;38;2;116;199;236:*.hxx=0;38;2;166;227;161:*.tmp=0;38;2;88;91;112:*.mli=0;38;2;166;227;161:*.def=0;38;2;166;227;161:*.clj=0;38;2;166;227;161:*.dox=0;38;2;148;226;213:*.git=0;38;2;88;91;112:*.deb=4;38;2;116;199;236:*.inl=0;38;2;166;227;161:*.tsx=0;38;2;166;227;161:*.xlr=0;38;2;243;139;168:*.bcf=0;38;2;88;91;112:*.dot=0;38;2;166;227;161:*.out=0;38;2;88;91;112:*.php=0;38;2;166;227;161:*.bsh=0;38;2;166;227;161:*.ttf=0;38;2;242;205;205:*.sbt=0;38;2;166;227;161:*.m4v=0;38;2;242;205;205:*.pod=0;38;2;166;227;161:*.bag=4;38;2;116;199;236:*.csx=0;38;2;166;227;161:*.pyd=0;38;2;88;91;112:*.psd=0;38;2;242;205;205:*.fls=0;38;2;88;91;112:*.ppt=0;38;2;243;139;168:*.ini=0;38;2;249;226;175:*.dll=1;38;2;243;139;168:*.elm=0;38;2;166;227;161:*.blg=0;38;2;88;91;112:*.xcf=0;38;2;242;205;205:*.avi=0;38;2;242;205;205:*.htc=0;38;2;166;227;161:*.fnt=0;38;2;242;205;205:*.log=0;38;2;88;91;112:*.epp=0;38;2;166;227;161:*.toc=0;38;2;88;91;112:*.cpp=0;38;2;166;227;161:*.bin=4;38;2;116;199;236:*.zsh=0;38;2;166;227;161:*.fsi=0;38;2;166;227;161:*.pro=0;38;2;148;226;213:*.vob=0;38;2;242;205;205:*.iso=4;38;2;116;199;236:*.ogg=0;38;2;242;205;205:*.cxx=0;38;2;166;227;161:*.cfg=0;38;2;249;226;175:*.h++=0;38;2;166;227;161:*.rst=0;38;2;249;226;175:*.erl=0;38;2;166;227;161:*.gvy=0;38;2;166;227;161:*.inc=0;38;2;166;227;161:*.flv=0;38;2;242;205;205:*.odt=0;38;2;243;139;168:*.wav=0;38;2;242;205;205:*.bak=0;38;2;88;91;112:*.pid=0;38;2;88;91;112:*.bib=0;38;2;249;226;175:*.pkg=4;38;2;116;199;236:*.ipp=0;38;2;166;227;161:*.swf=0;38;2;242;205;205:*.tar=4;38;2;116;199;236:*.vcd=4;38;2;116;199;236:*.exs=0;38;2;166;227;161:*.cgi=0;38;2;166;227;161:*.arj=4;38;2;116;199;236:*.lua=0;38;2;166;227;161:*.ind=0;38;2;88;91;112:*.hpp=0;38;2;166;227;161:*.pas=0;38;2;166;227;161:*.png=0;38;2;242;205;205:*.eps=0;38;2;242;205;205:*.rtf=0;38;2;243;139;168:*.rpm=4;38;2;116;199;236:*.odp=0;38;2;243;139;168:*.idx=0;38;2;88;91;112:*.gif=0;38;2;242;205;205:*.sxw=0;38;2;243;139;168:*.doc=0;38;2;243;139;168:*.swp=0;38;2;88;91;112:*.awk=0;38;2;166;227;161:*.tbz=4;38;2;116;199;236:*.txt=0;38;2;249;226;175:*.xls=0;38;2;243;139;168:*.exe=1;38;2;243;139;168:*.zst=4;38;2;116;199;236:*.dpr=0;38;2;166;227;161:*.mpg=0;38;2;242;205;205:*.bmp=0;38;2;242;205;205:*.mir=0;38;2;166;227;161:*.tcl=0;38;2;166;227;161:*.mp3=0;38;2;242;205;205:*.pyc=0;38;2;88;91;112:*.ilg=0;38;2;88;91;112:*.tex=0;38;2;166;227;161:*.tif=0;38;2;242;205;205:*.flac=0;38;2;242;205;205:*.yaml=0;38;2;249;226;175:*.epub=0;38;2;243;139;168:*.psd1=0;38;2;166;227;161:*.conf=0;38;2;249;226;175:*.tbz2=4;38;2;116;199;236:*.mpeg=0;38;2;242;205;205:*.java=0;38;2;166;227;161:*.dart=0;38;2;166;227;161:*.opus=0;38;2;242;205;205:*.purs=0;38;2;166;227;161:*.bash=0;38;2;166;227;161:*.h264=0;38;2;242;205;205:*.docx=0;38;2;243;139;168:*.xlsx=0;38;2;243;139;168:*.psm1=0;38;2;166;227;161:*.webm=0;38;2;242;205;205:*.hgrc=0;38;2;148;226;213:*.less=0;38;2;166;227;161:*.jpeg=0;38;2;242;205;205:*.diff=0;38;2;166;227;161:*.lock=0;38;2;88;91;112:*.html=0;38;2;249;226;175:*.tiff=0;38;2;242;205;205:*.pptx=0;38;2;243;139;168:*.toml=0;38;2;249;226;175:*.orig=0;38;2;88;91;112:*.fish=0;38;2;166;227;161:*.make=0;38;2;148;226;213:*.lisp=0;38;2;166;227;161:*.json=0;38;2;249;226;175:*.rlib=0;38;2;88;91;112:*.shtml=0;38;2;249;226;175:*.scala=0;38;2;166;227;161:*.cache=0;38;2;88;91;112:*.toast=4;38;2;116;199;236:*.cmake=0;38;2;148;226;213:*.ipynb=0;38;2;166;227;161:*README=0;38;2;30;30;46;48;2;249;226;175:*shadow=0;38;2;249;226;175:*.swift=0;38;2;166;227;161:*.dyn_o=0;38;2;88;91;112:*.class=0;38;2;88;91;112:*.xhtml=0;38;2;249;226;175:*.mdown=0;38;2;249;226;175:*.patch=0;38;2;166;227;161:*.cabal=0;38;2;166;227;161:*passwd=0;38;2;249;226;175:*TODO.md=1:*LICENSE=0;38;2;147;153;178:*.groovy=0;38;2;166;227;161:*.gradle=0;38;2;166;227;161:*INSTALL=0;38;2;30;30;46;48;2;249;226;175:*COPYING=0;38;2;147;153;178:*.flake8=0;38;2;148;226;213:*.dyn_hi=0;38;2;88;91;112:*.ignore=0;38;2;148;226;213:*.matlab=0;38;2;166;227;161:*.config=0;38;2;249;226;175:*.desktop=0;38;2;249;226;175:*setup.py=0;38;2;148;226;213:*Doxyfile=0;38;2;148;226;213:*.gemspec=0;38;2;148;226;213:*Makefile=0;38;2;148;226;213:*TODO.txt=1:*COPYRIGHT=0;38;2;147;153;178:*.kdevelop=0;38;2;148;226;213:*README.md=0;38;2;30;30;46;48;2;249;226;175:*.rgignore=0;38;2;148;226;213:*.markdown=0;38;2;249;226;175:*.DS_Store=0;38;2;88;91;112:*.fdignore=0;38;2;148;226;213:*configure=0;38;2;148;226;213:*.cmake.in=0;38;2;148;226;213:*Dockerfile=0;38;2;249;226;175:*README.txt=0;38;2;30;30;46;48;2;249;226;175:*.gitignore=0;38;2;148;226;213:*SConstruct=0;38;2;148;226;213:*INSTALL.md=0;38;2;30;30;46;48;2;249;226;175:*CODEOWNERS=0;38;2;148;226;213:*.gitconfig=0;38;2;148;226;213:*SConscript=0;38;2;148;226;213:*.scons_opt=0;38;2;88;91;112:*.localized=0;38;2;88;91;112:*Makefile.in=0;38;2;88;91;112:*Makefile.am=0;38;2;148;226;213:*LICENSE-MIT=0;38;2;147;153;178:*.synctex.gz=0;38;2;88;91;112:*INSTALL.txt=0;38;2;30;30;46;48;2;249;226;175:*.gitmodules=0;38;2;148;226;213:*.travis.yml=0;38;2;166;227;161:*MANIFEST.in=0;38;2;148;226;213:*appveyor.yml=0;38;2;166;227;161:*.fdb_latexmk=0;38;2;88;91;112:*CONTRIBUTORS=0;38;2;30;30;46;48;2;249;226;175:*configure.ac=0;38;2;148;226;213:*.applescript=0;38;2;166;227;161:*.clang-format=0;38;2;148;226;213:*.gitattributes=0;38;2;148;226;213:*CMakeCache.txt=0;38;2;88;91;112:*CMakeLists.txt=0;38;2;148;226;213:*LICENSE-APACHE=0;38;2;147;153;178:*CONTRIBUTORS.md=0;38;2;30;30;46;48;2;249;226;175:*requirements.txt=0;38;2;148;226;213:*CONTRIBUTORS.txt=0;38;2;30;30;46;48;2;249;226;175:*.sconsign.dblite=0;38;2;88;91;112:*package-lock.json=0;38;2;88;91;112:*.CFUserTextEncoding=0;38;2;88;91;112'
export COLUMNS
export FZF_PREVIEW_COLUMNS

# Setup Global and Local History
#setopt share_history

# Local History
function up-line-or-local-history() {
    zle set-local-history 1
    zle up-line-or-history
    zle set-local-history 0
}

function down-line-or-local-history() {
    zle set-local-history 1
    zle down-line-or-history
    zle set-local-history 0
}

zle -N up-line-or-local-history
zle -N down-line-or-local-history

bindkey "${key[Up]}" up-line-or-local-history
#bindkey "${key[Up]}" up-line-or-beginning-search
bindkey "${key[Down]}" down-line-or-local-history
#bindkey "${key[Down]}" down-line-or-beginning-search
bindkey "^[[1;5A" up-line-or-search    # [CTRL] + Cursor up
bindkey "^[[1;5B" down-line-or-search  # [CTRL] + Cursor down
#bindkey "^[[1;3A" up-line-or-local-history    # [ALT] + Cursor up
bindkey "^[[1;3A" up-line-or-beginning-search   # [ALT] + Cursor up
#bindkey "^[[1;3B" down-line-or-local-history  # [ALT] + Cursor up
bindkey "^[[1;3B" down-line-or-beginning-search  # [ALT] + Cursor up

# Source in existing bash profile and aliases
[[ -f ~/.bash_profile ]] && source ~/.bash_profile
[[ -f ~/.bash_aliases ]] && source ~/.bash_aliases

# NVM - Node Version Manager
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[[ -s "$NVM_DIR/bash_completion" ]] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Carapace Shell Completion Support
if which carapace >/dev/null; then 
    export CARAPACE_BRIDGES='zsh,bash,cobra,inshellisense' # optional
    zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
    zstyle ':completion:*:git:*' group-order 'main commands' 'alias commands' 'external commands'
    source <(carapace _carapace)
fi

# JWT Shell Completion Support
hash jwt >/dev/null && source <(jwt completion zsh)

# Fuzzy Finder Support
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# Forgit Support
[[ -f $ZSH/custom/plugins/forgit/forgit.plugin.zsh ]] && source $ZSH/custom/plugins/forgit/forgit.plugin.zsh

# Zoxide Support
which zoxide >/dev/null && eval "$(zoxide init zsh)"

# Xpanes Support
[[ -f $ZSH/custom/plugins/tmux-xpanes/completion.zsh ]] && source $ZSH/custom/plugins/tmux-xpanes/completion.zsh

# Starship Shell
which starship >/dev/null && eval "$(starship init zsh)"
