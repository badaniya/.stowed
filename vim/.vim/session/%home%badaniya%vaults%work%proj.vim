let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"nvo/issues/NVO-7458_G2_Periodic_Discovery_Not_Occurring.md\" }, { name = \"~/.private_zsh_functions\" } }"
let VimuxTmuxCommand = "tmux"
let VimuxPromptString = "Command? "
let VimuxResetSequence = "C-u"
let VimuxOpenExtraArgs = ""
let VimuxOrientation = "v"
let VimuxRunnerName = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
silent only
silent tabonly
cd ~/vaults/work/proj
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +35 ~/vaults/work/proj/nvo/issues/NVO-7458_G2_Periodic_Discovery_Not_Occurring.md
badd +1 ~/.private_zsh_functions
argglobal
%argdel
$argadd ~/.private_zsh_functions
edit ~/.private_zsh_functions
argglobal
balt ~/vaults/work/proj/nvo/issues/NVO-7458_G2_Periodic_Discovery_Not_Occurring.md
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
let s:l = 1618 - ((37 * winheight(0) + 36) / 73)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1618
normal! 05|
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
