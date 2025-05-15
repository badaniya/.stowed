let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let Db_ui_buffer_name_generator =  0 
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let Db_ui_table_name_sorter =  0 
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestGreenfieldPartialDeviceDiscoveryCreationOnPublishError$'\\'' ./Test/src/test/network/unit/usecase/devicediscovery'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestGreenfieldPartialDeviceDiscoveryCreationOnPublishError$' ./Test/src/test/network/unit/usecase/devicediscovery"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Test/src/test/network/unit/usecase/devicediscovery/device_discovery_test.go\", pinned = true }, { name = \"Network/src/network/usecase/onboarding.go\", pinned = true }, { name = \"Network/src/network/usecase/discovery.go\", pinned = true }, { name = \"Common/src/gateway/database/generic_operations.go\" }, { name = \"Network/src/network/usecase/collector/system_collector.go\" }, { name = \"Common/src/gateway/database/core_operations.go\" }, { name = \"RunOnce/src/runonce/main.go\" }, { name = \"RunOnce/src/runonce/utils/trigger_brownfield_device_onboarding.go\" }, { name = \"RunOnce/src/runonce/usecase/grpc_onboarding.go\" }, { name = \"RunOnce/src/runonce/usecase/interactorinterface/external_grpc_adapter.go\" }, { name = \"RunOnce/src/runonce/gateway/external_grpc_adapter.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/clientconn.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/transport/transport.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/keepalive/keepalive.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/transport/http2_client.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/transport/defaults.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/dialoptions.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/mem/buffer_pool.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/backoff/backoff.go\" }, { name = \"/usr/local/go/src/context/context.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/call.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/balancer_wrapper.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/stream.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/resolver/config_selector.go\" }, { name = \"~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/binarylog/method_logger.go\" }, { name = \"Common/src/domain/models/network/slot.go\" }, { name = \"Common/src/domain/models/inferred/slot.go\" }, { name = \"Common/src/gateway/database/read_options.go\" }, { name = \"Common/src/gateway/database/write_options.go\" }, { name = \"Common/src/domain/models/network/device.go\" }, { name = \"Common/src/domain/models/inferred/managed_device.go\" }, { name = \"Common/src/domain/models/network/device_connection_detail.go\" }, { name = \"Common/src/domain/models/network/location.go\" }, { name = \"Common/src/domain/models/network/data_structure.go\" }, { name = \"Common/src/domain/models/network/lldp.go\" }, { name = \"Common/src/domain/utils/utils.go\" }, { name = \"Network/src/network/usecase/collector/port_collector.go\" }, { name = \"~/.local/share/db_ui/nvo_db/scheduled_devices\" }, { name = \"uinvo/server/CommonServicesApiSpec/CommonApiSpec.yaml\" }, { name = \"Common/src/infra/system/auth.go\" }, { name = \"Common/src/infra/system/id_generator.go\" }, { name = \"Test/src/test/Common/unit/middleware/header_test.go\" }, { name = \"~/.go/pkg/mod/gorm.io/gorm@v1.25.12/clause/clause.go\" }, { name = \"Network/src/network/usecase/correlator/device_correlator.go\" } }"
let VimuxRunnerIndex = "%129"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-5930/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +84 Network/src/network/usecase/discovery.go
badd +692 Test/src/test/network/unit/usecase/devicediscovery/device_discovery_test.go
badd +646 Network/src/network/usecase/onboarding.go
badd +1139 Network/src/network/usecase/correlator/device_correlator.go
badd +94 Common/src/domain/models/inferred/managed_device.go
badd +47 Common/src/domain/models/network/slot.go
badd +114 Common/src/gateway/database/read_options.go
badd +51 Common/src/gateway/database/write_options.go
badd +57 Common/src/gateway/database/generic_operations.go
badd +89 Network/src/network/usecase/collector/system_collector.go
badd +71 Network/src/network/usecase/collector/port_collector.go
badd +194 Common/src/gateway/database/core_operations.go
badd +127 RunOnce/src/runonce/main.go
badd +52 RunOnce/src/runonce/utils/trigger_brownfield_device_onboarding.go
badd +143 RunOnce/src/runonce/usecase/grpc_onboarding.go
badd +27 RunOnce/src/runonce/usecase/interactorinterface/external_grpc_adapter.go
badd +1 RunOnce/src/runonce/gateway/external_grpc_adapter.go
badd +573 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/clientconn.go
badd +134 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/stream.go
badd +705 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/transport/transport.go
badd +265 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/transport/http2_client.go
badd +39 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/keepalive/keepalive.go
badd +33 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/transport/defaults.go
badd +701 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/dialoptions.go
badd +64 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/mem/buffer_pool.go
badd +45 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/backoff/backoff.go
badd +236 /usr/local/go/src/context/context.go
badd +318 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/balancer_wrapper.go
badd +41 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/call.go
badd +164 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/resolver/config_selector.go
badd +57 ~/.go/pkg/mod/google.golang.org/grpc@v1.68.0/internal/binarylog/method_logger.go
badd +16 Common/src/domain/models/inferred/slot.go
badd +41 Common/src/domain/models/network/device.go
badd +49 Common/src/domain/models/network/device_connection_detail.go
badd +24 Common/src/domain/models/network/location.go
badd +1 Common/src/domain/models/network/data_structure.go
badd +33 Common/src/domain/models/network/lldp.go
badd +41 Common/src/domain/utils/utils.go
badd +16 ~/.local/share/db_ui/nvo_db/scheduled_devices
badd +5 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/uinvo/server/CommonServicesApiSpec/CommonApiSpec.yaml
badd +95 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Common/src/infra/system/auth.go
badd +40 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Common/src/infra/system/id_generator.go
badd +97 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Test/src/test/Common/unit/middleware/header_test.go
badd +68 ~/.go/pkg/mod/gorm.io/gorm@v1.25.12/clause/clause.go
argglobal
%argdel
edit Network/src/network/usecase/onboarding.go
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt Test/src/test/network/unit/usecase/devicediscovery/device_discovery_test.go
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
let s:l = 646 - ((19 * winheight(0) + 25) / 51)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 646
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
