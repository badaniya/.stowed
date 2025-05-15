let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/Test
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +26 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/System/src/system/main.go
badd +91 src/test/network/functional/usecase/device_discovery_test.go
badd +1 src/test/network/functional/usecase/location_event_test.go
badd +763 src/test/network/functional/usecase/device_onboarding_test.go
badd +1 src/test/network/functional/usecase/device_delete_event_test.go
badd +2402 src/test/network/testutils/utils.go
badd +31 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/Network/Jenkinsfile
badd +92 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/Network/src/network/infra/initializer.go
badd +34 src/test/network/functional/usecase/usecase_main_test.go
badd +248 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/Common/src/infra/messaging/connector.go
badd +25 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/Common/src/infra/configs/messaging.go
badd +68 src/test/network/functional/usecase/device_location_change_test.go
badd +99 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/Common/src/infra/eventing/events/model/constants.go
badd +14 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/Common/src/infra/messaging/messaging_interface.go
badd +12 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/Common/src/infra/messaging/connectorinterface/connector_interface.go
badd +1 Common/src/infra/messaging/messaging_interface.go
badd +1 Test/Common/src/infra/messaging/messaging_interface.go
badd +1 Test/Test/Common/src/infra/messaging/messaging_interface.go
badd +1 Test/Test/Test/Common/src/infra/messaging/messaging_interface.go
badd +156 src/test/config/constants_device_list.go
badd +26 src/test/network/config/constants_dev.go
badd +35 src/test/network/config/constants_ci.go
badd +89 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/scripts/development/inlet/README.MD
badd +150 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/scripts/development/xiqemu/common_xiq_emulator_setup_readme.md
badd +49 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/scripts/development/xiqemu/xiq_emulator_debugging_inlets_readme.md
badd +170 src/test/edge/test/testutils/mocked_devices.go
badd +249 src/test/network/testutils/mocked_devices.go
badd +74 ~/workspace/badaniya/NVO-3613/GoDCApp/NVO/Network/src/network/usecase/telegraf.go
argglobal
%argdel
edit src/test/network/functional/usecase/device_delete_event_test.go
argglobal
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
let s:l = 1 - ((0 * winheight(0) + 25) / 51)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1
normal! 0
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
