let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/.stowed/README.md\", pinned = true }, { name = \"~/.stowed/nested_git_repos.md\", pinned = true }, { name = \"~/.stowed/tmux/.tmux.conf\", pinned = true }, { name = \"~/.stowed/starship/.config/starship.toml\", pinned = true }, { name = \"init.lua\", pinned = true } }"
let VimuxTmuxCommand = "tmux"
let VimuxPromptString = "Command? "
let VimuxResetSequence = "q C-u"
let VimuxOpenExtraArgs = ""
let VimuxOrientation = "v"
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
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
badd +924 nvim/.config/nvim/init.lua
badd +46 starship/.config/starship.toml
badd +16 tmux/.tmux.conf
badd +103 README.md
badd +64 nested_git_repos.md
badd +1 nvim/.config/nvim/lua/custom/plugins/vim-prosessions.lua
badd +24 nvim/.config/nvim/lua/custom/plugins/obsidian.lua
badd +60 nvim/.config/nvim/lua/custom/plugins/barbar.lua
badd +1 lua/custom/plugins/vim-prosessions.lua
argglobal
%argdel
edit nvim/.config/nvim/init.lua
argglobal
balt nvim/.config/nvim/lua/custom/plugins/barbar.lua
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
silent! normal! zE
let &fdl = &fdl
let s:l = 924 - ((20 * winheight(0) + 36) / 73)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 924
normal! 06|
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
let g:this_session = v:this_session
let g:this_obsession = v:this_session
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
