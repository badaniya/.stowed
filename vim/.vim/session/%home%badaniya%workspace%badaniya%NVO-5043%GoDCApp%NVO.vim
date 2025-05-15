let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestRunOnce_GetGrcpDeviceInfoAndPublish$'\\'' ./Test/src/test/runonce/functional/grpc_onboarding'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestRunOnce_GetGrcpDeviceInfoAndPublish$' ./Test/src/test/runonce/functional/grpc_onboarding"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"NVO/System/src/system/usecase/physical_link.go\" }, { name = \"NVO/Network/src/network/usecase/discovery.go\" }, { name = \"NVO/Network/src/network/usecase/gateway_interactor.go\" }, { name = \"NVO/Network/src/network/infra/initializer.go\" }, { name = \"NVO/Network/src/network/gateway/device_adapter_factory.go\" }, { name = \"GoSwitch/src/goswitch/device/deviceadapter.go\" }, { name = \"NVO/Common/src/domain/models/network/device_connection_detail.go\" }, { name = \"GoSwitch/src/goswitch/device/session/Repository.go\" }, { name = \"GoSwitch/src/goswitch/device/adapter/SwitchGNMIAdapter.go\" }, { name = \"GoSwitch/src/goswitch/device/client/gnmi/client/client.go\" }, { name = \"GoSwitch/src/goswitch/device/adapter/InletRestAdapter.go\" } }"
let VimuxRunnerIndex = "%44"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-5043/GoDCApp
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +29 NVO/System/src/system/usecase/physical_link.go
badd +163 NVO/Network/src/network/usecase/discovery.go
badd +31 NVO/Network/src/network/usecase/gateway_interactor.go
badd +60 NVO/Network/src/network/infra/initializer.go
badd +24 NVO/Network/src/network/gateway/device_adapter_factory.go
badd +382 GoSwitch/src/goswitch/device/deviceadapter.go
badd +41 NVO/Common/src/domain/models/network/device_connection_detail.go
badd +898 GoSwitch/src/goswitch/device/session/Repository.go
badd +34 GoSwitch/src/goswitch/device/adapter/SwitchGNMIAdapter.go
badd +73 GoSwitch/src/goswitch/device/adapter/InletRestAdapter.go
badd +67 GoSwitch/src/goswitch/device/client/gnmi/client/client.go
argglobal
%argdel
edit GoSwitch/src/goswitch/device/session/Repository.go
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt GoSwitch/src/goswitch/device/adapter/InletRestAdapter.go
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
let s:l = 898 - ((17 * winheight(0) + 31) / 63)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 898
normal! 058|
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
