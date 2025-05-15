let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/vaults/work/proj\" } }"
let SessionLoad =  1 
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/vaults/work/proj/nvim
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +362 ~/vaults/work/proj/nvo/issues/NVO-4663.md
badd +1 ~/vaults/work/proj/nvo/24.2.0/nvo-4663_meeting_minutes.md
badd +48 ~/vaults/work/proj/nvo/network_ci_docker/network_service_docker_test_update_0424.md
badd +0 ~/vaults/work/proj/neo-tree\ filesystem\ \[1]
argglobal
%argdel
edit ~/vaults/work/proj/neo-tree\ filesystem\ \[1]
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 43 + 147) / 294)
exe 'vert 2resize ' . ((&columns * 250 + 147) / 294)
tcd ~/vaults/work/proj
argglobal
balt ~/vaults/work/proj/nvo/issues/NVO-4663.md
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
let s:l = 1 - ((0 * winheight(0) + 37) / 75)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1
normal! 0
wincmd w
argglobal
if bufexists(fnamemodify("~/vaults/work/proj/nvo/24.2.0/nvo-4663_meeting_minutes.md", ":p")) | buffer ~/vaults/work/proj/nvo/24.2.0/nvo-4663_meeting_minutes.md | else | edit ~/vaults/work/proj/nvo/24.2.0/nvo-4663_meeting_minutes.md | endif
if &buftype ==# 'terminal'
  silent file ~/vaults/work/proj/nvo/24.2.0/nvo-4663_meeting_minutes.md
endif
balt ~/vaults/work/proj/nvo/network_ci_docker/network_service_docker_test_update_0424.md
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
let s:l = 1 - ((0 * winheight(0) + 37) / 75)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1
normal! 0
wincmd w
2wincmd w
exe 'vert 1resize ' . ((&columns * 43 + 147) / 294)
exe 'vert 2resize ' . ((&columns * 250 + 147) / 294)
tabnext 1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=1
let &shortmess = s:shortmess_save
let &winminheight = s:save_winminheight
let &winminwidth = s:save_winminwidth
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
