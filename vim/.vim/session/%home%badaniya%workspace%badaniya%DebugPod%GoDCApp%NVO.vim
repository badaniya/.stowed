let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Debug/scripts/Dockerfile\" }, { name = \"Network/src/network/usecase/location_change.go\" }, { name = \"RunOnce/src/runonce/usecase/grpc_onboarding.go\" }, { name = \"RunOnce/src/runonce/main.go\" }, { name = \"RunOnce/src/runonce/infra/configs/setup.go\" }, { name = \"Common/src/infra/configs/application.go\" }, { name = \"RunOnce/src/runonce/utils/trigger_brownfield_device_onboarding.go\" }, { name = \"RunOnce/src/runonce/usecase/interactorinterface/external_grpc_adapter.go\" }, { name = \"RunOnce/src/runonce/gateway/external_grpc_adapter.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/dialoptions.go\" }, { name = \"System/src/system/usecase/device.go\" }, { name = \"Network/src/network/usecase/onboarding.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/DebugPod/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +30 Debug/scripts/Dockerfile
badd +127 ~/workspace/badaniya/DebugPod/GoDCApp/NVO/Network/src/network/usecase/location_change.go
badd +44 ~/workspace/badaniya/DebugPod/GoDCApp/NVO/RunOnce/src/runonce/usecase/grpc_onboarding.go
badd +66 ~/workspace/badaniya/DebugPod/GoDCApp/NVO/RunOnce/src/runonce/main.go
badd +24 ~/workspace/badaniya/DebugPod/GoDCApp/NVO/RunOnce/src/runonce/infra/configs/setup.go
badd +206 ~/workspace/badaniya/DebugPod/GoDCApp/NVO/Common/src/infra/configs/application.go
badd +43 ~/workspace/badaniya/DebugPod/GoDCApp/NVO/RunOnce/src/runonce/utils/trigger_brownfield_device_onboarding.go
badd +27 ~/workspace/badaniya/DebugPod/GoDCApp/NVO/RunOnce/src/runonce/usecase/interactorinterface/external_grpc_adapter.go
badd +50 ~/workspace/badaniya/DebugPod/GoDCApp/NVO/RunOnce/src/runonce/gateway/external_grpc_adapter.go
badd +398 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/dialoptions.go
badd +138 System/src/system/usecase/device.go
badd +1 ~/workspace/badaniya/DebugPod/GoDCApp/NVO/Network/src/network/usecase/onboarding.go
argglobal
%argdel
edit ~/workspace/badaniya/DebugPod/GoDCApp/NVO/Network/src/network/usecase/onboarding.go
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
wincmd =
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt ~/workspace/badaniya/DebugPod/GoDCApp/NVO/RunOnce/src/runonce/usecase/grpc_onboarding.go
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
balt Debug/scripts/Dockerfile
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
let s:l = 71 - ((25 * winheight(0) + 38) / 76)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 71
normal! 0
wincmd w
2wincmd w
wincmd =
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
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
