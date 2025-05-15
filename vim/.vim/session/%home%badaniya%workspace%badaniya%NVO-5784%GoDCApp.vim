let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Db_ui_buffer_name_generator =  0 
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let Db_ui_table_name_sorter =  0 
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"GoSwitch/src/goswitch/device/session/Repository.go\" }, { name = \"GoSwitch/src/goswitch/domain/adapter.go\" }, { name = \"GoSwitch/src/goswitch/domain/device.go\" }, { name = \"GoSwitch/src/goswitch/constants/constants.go\" }, { name = \"GoSwitch/src/goswitch/test/campustest/nos/main_nos_campus_test.go\" }, { name = \"GoSwitch/src/goswitch/test/campustest/helper/device_test_helper.go\" }, { name = \"GoSwitch/src/goswitch/test/campustest/nos/spbm_test.go\" }, { name = \"GoSwitch/src/goswitch/test/device/session/repository_test.go\" }, { name = \"GoSwitch/src/goswitch/test/device/device_adapter_test.go\" }, { name = \"GoSwitch/src/goswitch/device/deviceadapter.go\" }, { name = \"GoSwitch/src/goswitch/device/platforms/slx/hardwareaction.go\" }, { name = \"GoSwitch/src/goswitch/test/campustest/exos/auth_test.go\" }, { name = \"GoSwitch/src/goswitch/test/campustest/exos/system_services_test.go\" }, { name = \"GoSwitch/src/goswitch/test/campustest/exos/systemCli_test.go\" }, { name = \"GoSwitch/src/goswitch/test/campustest/voss/vlan_test.go\" }, { name = \"GoSwitch/src/goswitch/test/campustest/voss/main_voss_campus_test.go\" }, { name = \"GoSwitch/src/goswitch/test/campustest/voss/interface_test.go\" }, { name = \"~/.local/share/db_ui/nvo_db/scheduled_devices\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-5784/GoDCApp
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +1218 GoSwitch/src/goswitch/device/session/Repository.go
badd +58 GoSwitch/src/goswitch/domain/adapter.go
badd +616 GoSwitch/src/goswitch/domain/device.go
badd +191 GoSwitch/src/goswitch/constants/constants.go
badd +23 GoSwitch/src/goswitch/test/campustest/nos/main_nos_campus_test.go
badd +56 GoSwitch/src/goswitch/test/campustest/nos/spbm_test.go
badd +324 GoSwitch/src/goswitch/test/campustest/helper/device_test_helper.go
badd +83 GoSwitch/src/goswitch/test/device/session/repository_test.go
badd +490 GoSwitch/src/goswitch/test/device/device_adapter_test.go
badd +50 GoSwitch/src/goswitch/device/deviceadapter.go
badd +0 GoSwitch/src/goswitch/device/platforms/slx/hardwareaction.go
badd +49 GoSwitch/src/goswitch/test/campustest/exos/auth_test.go
badd +65 GoSwitch/src/goswitch/test/campustest/exos/system_services_test.go
badd +1 GoSwitch/src/goswitch/test/campustest/exos/systemCli_test.go
badd +26 GoSwitch/src/goswitch/test/campustest/voss/vlan_test.go
badd +884 GoSwitch/src/goswitch/test/campustest/voss/interface_test.go
badd +62 GoSwitch/src/goswitch/test/campustest/voss/main_voss_campus_test.go
badd +16 ~/.local/share/db_ui/nvo_db/scheduled_devices
argglobal
%argdel
argglobal
enew
file neo-tree\ filesystem\ \[5]
balt GoSwitch/src/goswitch/device/session/Repository.go
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
