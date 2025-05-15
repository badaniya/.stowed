let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Common/src/gateway/database/logging/logging.go\" }, { name = \"Common/src/domain/models/system/logging.go\" }, { name = \"Common/src/domain/models/base.go\" }, { name = \"Common/src/infra/utils/logging.go\" }, { name = \"Common/src/infra/utils/application.go\" }, { name = \"Common/src/infra/utils/collector_staging.go\" }, { name = \"Common/src/infra/lock/constants.go\" }, { name = \"Common/src/infra/lock/event_handler.go\" }, { name = \"Common/src/infra/lock/DistributedLock.go\" }, { name = \"Common/src/infra/constants/common.go\" }, { name = \"Common/src/infra/constants/context_values.go\" }, { name = \"Common/src/infra/constants/orchestrator_constants.go\" }, { name = \"Common/src/infra/constants/queryParamsConstants.go\" }, { name = \"Common/src/domain/uuid/binary_uuid.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6397/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +7 Common/src/gateway/database/logging/logging.go
badd +21 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/domain/models/base.go
badd +1 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/utils/application.go
badd +1 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/utils/logging.go
badd +62 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/lock/DistributedLock.go
badd +1 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/utils/collector_staging.go
badd +17 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/domain/models/system/logging.go
badd +27 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/lock/constants.go
badd +1 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/lock/event_handler.go
badd +1 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/constants/common.go
badd +27 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/constants/context_values.go
badd +1 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/constants/orchestrator_constants.go
badd +9 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/constants/queryParamsConstants.go
badd +28 ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/domain/uuid/binary_uuid.go
argglobal
%argdel
edit ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/infra/constants/queryParamsConstants.go
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
exe 'vert 1resize ' . ((&columns * 40 + 102) / 205)
exe 'vert 2resize ' . ((&columns * 164 + 102) / 205)
argglobal
enew
file neo-tree\ filesystem\ \[1]
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
wincmd w
argglobal
balt ~/workspace/badaniya/NVO-6397/GoDCApp/NVO/Common/src/domain/uuid/binary_uuid.go
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
let s:l = 9 - ((8 * winheight(0) + 22) / 44)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 9
normal! 0
wincmd w
2wincmd w
exe 'vert 1resize ' . ((&columns * 40 + 102) / 205)
exe 'vert 2resize ' . ((&columns * 164 + 102) / 205)
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
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
