let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Network/src/network/main.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Network/src/network/usecase/onboarding.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Network/src/network/usecase/discovery.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Common/src/infra/nvoworker/constants.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Common/src/infra/eventing/events/model/events/device_onboard_event.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/RunOnce/src/runonce/main.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/RunOnce/src/runonce/utils/fetch_location_hierarchy.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/RunOnce/src/runonce/utils/trigger_brownfield_device_onboarding.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Common/src/gateway/usecase/location_hierarchy.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Common/src/interactorinterface/external_hive_adapter.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Common/src/gateway/usecase/external_hive_adapter.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Common/src/gateway/usecase/location_client.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/RunOnce/src/runonce/usecase/location_consistency.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/RunOnce/src/runonce/utils/fix_location_consistency.go\" }, { name = \"/usr/local/go/src/net/http/client.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Edge/src/edge/usecase/discovery.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Test/src/test/network/unit/usecase/scheduler/scheduler_event_main_test.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Test/src/test/network/unit/usecase/scheduler/scheduler_event_test.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Test/src/test/network/testutils/mocked_scheduler.go\" }, { name = \"~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Test/src/test/network/testutils/utils.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd 
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +261 Edge/src/edge/usecase/discovery.go
badd +48 Network/src/network/main.go
badd +205 Network/src/network/usecase/onboarding.go
badd +1115 Network/src/network/usecase/discovery.go
badd +1 Common/src/infra/nvoworker/constants.go
badd +100 Common/src/infra/eventing/events/model/events/device_onboard_event.go
badd +114 RunOnce/src/runonce/main.go
badd +49 RunOnce/src/runonce/utils/fetch_location_hierarchy.go
badd +51 RunOnce/src/runonce/utils/trigger_brownfield_device_onboarding.go
badd +48 Common/src/gateway/usecase/location_hierarchy.go
badd +23 Common/src/interactorinterface/external_hive_adapter.go
badd +39 Common/src/gateway/usecase/external_hive_adapter.go
badd +37 Common/src/gateway/usecase/location_client.go
badd +56 RunOnce/src/runonce/usecase/location_consistency.go
badd +37 RunOnce/src/runonce/utils/fix_location_consistency.go
badd +109 /usr/local/go/src/net/http/client.go
badd +1 ~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Test/src/test/network/unit/usecase/scheduler/scheduler_event_main_test.go
badd +32 ~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Test/src/test/network/unit/usecase/scheduler/scheduler_event_test.go
badd +147 ~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Test/src/test/network/testutils/mocked_scheduler.go
badd +217 ~/workspace/badaniya/NVO-4937/GoDCApp/NVO/Test/src/test/network/testutils/utils.go
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
balt Network/src/network/usecase/discovery.go
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
