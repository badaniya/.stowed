let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''Test_DeviceOnboardingWithInvalidOwnerID$'\\'' ./Test/src/test/network/functional/usecase'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'Test_DeviceOnboardingWithInvalidOwnerID$' ./Test/src/test/network/functional/usecase"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"RunOnce/src/runonce/usecase/grpc_onboarding.go\" }, { name = \"Network/src/network/usecase/onboarding.go\" }, { name = \"Common/src/infra/eventing/events/model/events/device_onboard_event.go\" }, { name = \"Network/src/network/infra/events/external_handler.go\" }, { name = \"Test/src/test/network/functional/usecase/device_onboarding_test.go\" }, { name = \"Common/src/infra/messaging/confluent_kafka/kafka_connector.go\" }, { name = \"Common/src/infra/eventing/events/model/externalevents/externaltopicstruct.go\" }, { name = \"Test/src/test/automation/infra/api/gui/guimanager/GuiOperations.go\" }, { name = \"Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_test.go\" }, { name = \"Common/src/gateway/usecase/location_hierarchy.go\" }, { name = \"Test/src/test/runonce/unit/location_hierarchy/hierarchy_data_multi.txt\" }, { name = \"Common/src/infra/configs/multitenancy.go\" }, { name = \"Common/src/interactorinterface/external_hive_adapter.go\" }, { name = \"Common/src/gateway/usecase/external_hive_adapter.go\" }, { name = \"Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_main_test.go\" }, { name = \"Network/src/network/usecase/collector/lldp_collector.go\" }, { name = \"Network/src/network/usecase/interactorinterface/device_adapter.go\" }, { name = \"Network/src/network/gateway/device_adapter.go\" }, { name = \"~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/model/lldp.go\" }, { name = \"~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/device/platforms/exos/exos_connector.go\" }, { name = \"~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/device/platforms/exos/base/LldpAction.go\" }, { name = \"~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/device/platforms/nos/base/LldpAction.go\" }, { name = \"~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/device/platforms/nos/base/Template.go\" }, { name = \"Network/src/network/usecase/correlator/physical_link_correlator.go\" }, { name = \"Common/src/domain/models/inferred/phyiscal_topology.go\" }, { name = \"Common/src/domain/models/inferred/physical_link.go\" }, { name = \"Common/src/domain/models/network/lldp_neighbor_state.go\" }, { name = \"Common/src/domain/comparator/comparator.go\" } }"
let VimuxRunnerIndex = "%23"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-5858/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +185 RunOnce/src/runonce/usecase/grpc_onboarding.go
badd +57 Network/src/network/usecase/onboarding.go
badd +73 Common/src/infra/eventing/events/model/events/device_onboard_event.go
badd +78 Network/src/network/infra/events/external_handler.go
badd +1234 Test/src/test/network/functional/usecase/device_onboarding_test.go
badd +277 Common/src/infra/messaging/confluent_kafka/kafka_connector.go
badd +19 Common/src/infra/eventing/events/model/externalevents/externaltopicstruct.go
badd +2 Test/src/test/automation/infra/api/gui/guimanager/GuiOperations.go
badd +1 Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_test.go
badd +60 Common/src/gateway/usecase/location_hierarchy.go
badd +23 Test/src/test/runonce/unit/location_hierarchy/hierarchy_data_multi.txt
badd +26 Common/src/infra/configs/multitenancy.go
badd +23 Common/src/interactorinterface/external_hive_adapter.go
badd +35 Common/src/gateway/usecase/external_hive_adapter.go
badd +20 Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_main_test.go
badd +420 Network/src/network/usecase/collector/lldp_collector.go
badd +61 Network/src/network/usecase/interactorinterface/device_adapter.go
badd +5406 Network/src/network/gateway/device_adapter.go
badd +350 ~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/model/lldp.go
badd +128 ~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/device/platforms/nos/base/LldpAction.go
badd +60 ~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/device/platforms/exos/exos_connector.go
badd +23 ~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/device/platforms/exos/base/LldpAction.go
badd +492 ~/workspace/badaniya/NVO-5858/GoDCApp/GoSwitch/src/goswitch/device/platforms/nos/base/Template.go
badd +187 Network/src/network/usecase/correlator/physical_link_correlator.go
badd +8 ~/workspace/badaniya/NVO-5858/GoDCApp/NVO/Common/src/domain/models/inferred/phyiscal_topology.go
badd +16 ~/workspace/badaniya/NVO-5858/GoDCApp/NVO/Common/src/domain/models/inferred/physical_link.go
badd +18 ~/workspace/badaniya/NVO-5858/GoDCApp/NVO/Common/src/domain/models/network/lldp_neighbor_state.go
badd +82 ~/workspace/badaniya/NVO-5858/GoDCApp/NVO/Common/src/domain/comparator/comparator.go
argglobal
%argdel
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_test.go
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
