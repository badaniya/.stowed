let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Common/src/infra/go.mod\", pinned = true }, { name = \"~/workspace/badaniya/NVO-6515/GoDCApp/GoSwitch/src/goswitch/go.mod\", pinned = true }, { name = \"RunOnce/src/runonce/go.mod\" }, { name = \"Network/src/network/go.mod\" }, { name = \"Network/src/network/main.go\" }, { name = \"Test/src/test/runonce/functional/grpc_onboarding/grpc_onboarding_test.go\" }, { name = \"Common/src/infra/grpc/grpcinfra.go\" }, { name = \"Common/src/infra/grpc/generated/xiqwirelessclient/location/s2s_location.pb.go\" }, { name = \"Common/src/infra/grpc/generated/xiqwirelessclient/location/s2s_location_service.pb.go\" }, { name = \"Common/src/infra/grpc/generated/xiqwirelessclient/location/s2s_location_service_grpc.pb.go\" }, { name = \"Common/src/infra/grpc/generated/xiqwirelessclient/s2s_device.pb.go\" }, { name = \"Network/src/network/usecase/ap_device_details.go\" } }"
let VimuxRunnerIndex = "%140"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestRunOnce_GetGrcpDeviceInfoAndPublish$'\\'' ./Test/src/test/runonce/functional/grpc_onboarding'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestRunOnce_GetGrcpDeviceInfoAndPublish$' ./Test/src/test/runonce/functional/grpc_onboarding"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6515/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +104 Common/src/infra/grpc/generated/xiqwirelessclient/location/s2s_location_service_grpc.pb.go
badd +39 Network/src/network/usecase/ap_device_details.go
badd +56 Test/src/test/runonce/functional/grpc_onboarding/grpc_onboarding_test.go
badd +1 Common/src/infra/grpc/generated/xiqwirelessclient/location/s2s_location.pb.go
badd +2083 Common/src/infra/grpc/generated/xiqwirelessclient/s2s_device.pb.go
badd +1 Common/src/infra/grpc/grpcinfra.go
badd +64 RunOnce/src/runonce/go.mod
badd +92 Network/src/network/go.mod
badd +79 Common/src/infra/go.mod
badd +34 ~/workspace/badaniya/NVO-6515/GoDCApp/GoSwitch/src/goswitch/go.mod
badd +97 ~/workspace/badaniya/NVO-6515/GoDCApp/NVO/Common/src/infra/grpc/generated/xiqwirelessclient/location/s2s_location_service.pb.go
badd +34 ~/workspace/badaniya/NVO-6515/GoDCApp/NVO/Network/src/network/main.go
argglobal
%argdel
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
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
