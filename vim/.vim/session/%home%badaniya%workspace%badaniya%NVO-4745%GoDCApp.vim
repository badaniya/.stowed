let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Network/src/network/main.go\" }, { name = \"Common/src/domain/comparator/comparator.go\" }, { name = \"Common/src/domain/comparator/set.go\" }, { name = \"Network/src/network/usecase/collector/system_collector.go\" }, { name = \"Common/src/gateway/database/generic_operations.go\" }, { name = \"Common/src/domain/utils/utils.go\" }, { name = \"Common/src/domain/models/network/stack_info.go\" }, { name = \"Common/src/domain/models/network/device_connection_detail.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-4745/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +66 Network/src/network/main.go
badd +76 ~/workspace/badaniya/NVO-4745/GoDCApp/NVO/Common/src/domain/comparator/comparator.go
badd +121 ~/workspace/badaniya/NVO-4745/GoDCApp/NVO/Common/src/domain/comparator/set.go
badd +1 ~/workspace/badaniya/NVO-4745/GoDCApp/NVO/Network/src/network/usecase/collector/system_collector.go
badd +195 ~/workspace/badaniya/NVO-4745/GoDCApp/NVO/Common/src/gateway/database/generic_operations.go
badd +16 ~/workspace/badaniya/NVO-4745/GoDCApp/NVO/Common/src/domain/utils/utils.go
badd +49 ~/workspace/badaniya/NVO-4745/GoDCApp/NVO/Common/src/domain/models/network/stack_info.go
badd +48 ~/workspace/badaniya/NVO-4745/GoDCApp/NVO/Common/src/domain/models/network/device_connection_detail.go
argglobal
%argdel
edit ~/workspace/badaniya/NVO-4745/GoDCApp/NVO/Network/src/network/usecase/collector/system_collector.go
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ~/workspace/badaniya/NVO-4745/GoDCApp/NVO/Common/src/domain/utils/utils.go
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
let s:l = 106 - ((19 * winheight(0) + 37) / 74)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 106
normal! 0
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
