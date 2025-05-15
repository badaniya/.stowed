let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Db_ui_buffer_name_generator =  0 
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let Db_ui_table_name_sorter =  0 
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all ./Test/src/test/network/unit/usecase/refreshtopology/...'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all ./Test/src/test/network/unit/usecase/refreshtopology/..."
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Network/src/network/usecase/websockets.go\" }, { name = \"Network/src/network/usecase/ap_device_data_collection_event.go\" }, { name = \"Network/src/network/infra/events/internal_handler.go\" }, { name = \"Common/src/infra/constants/context_values.go\" }, { name = \"Test/src/test/network/testutils/functional_utils.go\" }, { name = \"Test/src/test/network/testutils/utils.go\" }, { name = \"Common/src/infra/configs/database.go\" }, { name = \"Test/src/test/network/functional/usecase/orchestrator/orchestrator_test.go\" }, { name = \"Network/src/network/usecase/discovery.go\" }, { name = \"Test/src/test/network/unit/usecase/devicediscovery/device_discovery_test.go\" }, { name = \"Test/src/test/network/unit/usecase/refreshtopology/refresh_topology_test.go\" }, { name = \"Network/src/network/infra/events/external_handler.go\" }, { name = \"Network/src/network/usecase/internal_event_handler.go\" }, { name = \"Network/src/network/infra/rest/openapi/handler/refresh.go\" }, { name = \"Network/src/network/usecase/refresh.go\" }, { name = \"Network/src/network/infra/utils/lock_utils.go\" }, { name = \"scripts/deploy/helm/runonce/values.yaml\" } }"
let VimuxRunnerIndex = "%24"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-5542/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +373 Test/src/test/network/functional/usecase/orchestrator/orchestrator_test.go
badd +25 Test/src/test/network/testutils/functional_utils.go
badd +154 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Test/src/test/network/unit/usecase/devicediscovery/device_discovery_test.go
badd +65 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/infra/events/internal_handler.go
badd +28 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/usecase/websockets.go
badd +201 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/usecase/refresh.go
badd +266 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/usecase/discovery.go
badd +476 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Test/src/test/network/testutils/utils.go
badd +44 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/usecase/internal_event_handler.go
badd +71 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Common/src/infra/constants/context_values.go
badd +40 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/infra/utils/lock_utils.go
badd +14 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/usecase/ap_device_data_collection_event.go
badd +23 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Common/src/infra/configs/database.go
badd +138 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Test/src/test/network/unit/usecase/refreshtopology/refresh_topology_test.go
badd +73 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/infra/events/external_handler.go
badd +49 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/infra/rest/openapi/handler/refresh.go
badd +45 ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/scripts/deploy/helm/runonce/values.yaml
argglobal
%argdel
edit ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/scripts/deploy/helm/runonce/values.yaml
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ~/workspace/badaniya/NVO-5542/GoDCApp/NVO/Network/src/network/infra/utils/lock_utils.go
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
let s:l = 45 - ((43 * winheight(0) + 29) / 59)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 45
normal! 012|
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
