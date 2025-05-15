let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Common/src/domain/utils/utils.go\", pinned = true }, { name = \"Common/src/domain/comparator/comparator.go\", pinned = true }, { name = \"Edge/src/edge/usecase/collector/elrp_collector.go\" }, { name = \"Edge/src/edge/usecase/collector/igmp_collector.go\" }, { name = \"Edge/src/edge/main.go\" }, { name = \"Common/src/infra/utils/application.go\" }, { name = \"/usr/local/go/src/builtin/builtin.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/priv-jcarleton-24.3.0/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +30 Common/src/domain/utils/utils.go
badd +95 Common/src/domain/comparator/comparator.go
badd +54 ~/workspace/badaniya/priv-jcarleton-24.3.0/GoDCApp/NVO/Edge/src/edge/usecase/collector/elrp_collector.go
badd +68 ~/workspace/badaniya/priv-jcarleton-24.3.0/GoDCApp/NVO/Edge/src/edge/usecase/collector/igmp_collector.go
badd +79 ~/workspace/badaniya/priv-jcarleton-24.3.0/GoDCApp/NVO/Edge/src/edge/main.go
badd +23 ~/workspace/badaniya/priv-jcarleton-24.3.0/GoDCApp/NVO/Common/src/infra/utils/application.go
badd +291 /usr/local/go/src/builtin/builtin.go
argglobal
%argdel
edit ~/workspace/badaniya/priv-jcarleton-24.3.0/GoDCApp/NVO/Edge/src/edge/usecase/collector/igmp_collector.go
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ~/workspace/badaniya/priv-jcarleton-24.3.0/GoDCApp/NVO/Edge/src/edge/main.go
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
let s:l = 68 - ((25 * winheight(0) + 25) / 51)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 68
normal! 018|
tabnext 1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=20
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
let g:this_session = v:this_session
let g:this_obsession = v:this_session
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
