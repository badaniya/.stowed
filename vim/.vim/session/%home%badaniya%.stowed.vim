let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "q C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"README.md\", pinned = true }, { name = \"nested_git_repos.md\", pinned = true }, { name = \"ghostty/.config/ghostty/config\", pinned = true }, { name = \"tmux/.tmux.conf\", pinned = true }, { name = \"starship/.config/starship.toml\", pinned = true }, { name = \"nvim/.config/nvim/init.lua\", pinned = true }, { name = \"tmuxinator/.config/tmuxinator/ng-aio.yml\" }, { name = \"tmuxinator/.config/tmuxinator/cloud-testbed.yml\" }, { name = \"tmuxinator/.config/tmuxinator/cloud-testbed-cit.yml\" }, { name = \"tmuxinator/.config/tmuxinator/badaniya-dev.yml\" }, { name = \"tmuxinator/.config/tmuxinator/home-config.yml\" }, { name = \"tmuxinator/.config/tmuxinator/ng-aio-briana.yml\" }, { name = \"tmuxinator/.config/tmuxinator/ng-aio-pasu.yml\" }, { name = \"tmuxinator/.config/tmuxinator/ng-aio-wired3.yml\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/.stowed
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +742 nvim/.config/nvim/init.lua
badd +1 starship/.config/starship.toml
badd +1 tmux/.tmux.conf
badd +5 README.md
badd +1 nested_git_repos.md
badd +1 ghostty/.config/ghostty/config
badd +15 ~/.stowed/tmuxinator/.config/tmuxinator/ng-aio.yml
badd +1 ~/.stowed/tmuxinator/.config/tmuxinator/cloud-testbed.yml
badd +1 ~/.stowed/tmuxinator/.config/tmuxinator/cloud-testbed-cit.yml
badd +1 ~/.stowed/tmuxinator/.config/tmuxinator/badaniya-dev.yml
badd +1 ~/.stowed/tmuxinator/.config/tmuxinator/home-config.yml
badd +1 ~/.stowed/tmuxinator/.config/tmuxinator/ng-aio-briana.yml
badd +1 ~/.stowed/tmuxinator/.config/tmuxinator/ng-aio-pasu.yml
badd +1 ~/.stowed/tmuxinator/.config/tmuxinator/ng-aio-wired3.yml
argglobal
%argdel
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt ~/.stowed/tmuxinator/.config/tmuxinator/ng-aio.yml
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
tabnext 1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=20
let &shortmess = s:shortmess_save
let s:sx = expand("<sfile>:p:r")."x.vim"
if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &g:so = s:so_save | let &g:siso = s:siso_save
set hlsearch
nohlsearch
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
