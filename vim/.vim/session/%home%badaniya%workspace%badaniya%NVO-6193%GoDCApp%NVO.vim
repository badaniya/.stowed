let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestUnamangedToManagedDeviceDiscoveryWithNodeCoordinatesCleanup$'\\'' ./Test/src/test/network/functional/usecase'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestUnamangedToManagedDeviceDiscoveryWithNodeCoordinatesCleanup$' ./Test/src/test/network/functional/usecase"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Test/src/test/network/functional/usecase/device_discovery_test.go\", pinned = true }, { name = \"Network/src/network/usecase/onboarding.go\" }, { name = \"Test/src/test/network/functional/usecase/device_location_change_test.go\" }, { name = \"Network/src/network/usecase/correlator/device_correlator.go\" }, { name = \"Test/src/test/network/testutils/mocked_location.go\" }, { name = \"Network/src/network/usecase/discovery.go\" }, { name = \"Common/src/domain/models/inferred/managed_device.go\" }, { name = \"Test/src/test/network/testutils/mocked_scheduler.go\" }, { name = \"Test/src/test/network/config/constants_dev.go\" }, { name = \"Test/src/test/network/testutils/functional_utils.go\" }, { name = \"Common/src/domain/models/network/device_connection_detail.go\" }, { name = \"Test/src/test/config/constants_device_list.go\" }, { name = \"Test/src/test/network/functional/usecase/collector/mlag_collector_test.go\" }, { name = \"Network/src/network/infra/initializer.go\" }, { name = \"~/.go/pkg/mod/github.com/stretchr/testify@v1.10.0/require/require.go\" }, { name = \"Common/src/gateway/database/generic_operations.go\" }, { name = \"Common/src/infra/apperrors/nvoerror.go\" }, { name = \"Common/src/infra/utils/error_constants.go\" }, { name = \"Test/src/test/network/functional/usecase/device_onboarding_test.go\" }, { name = \"Test/src/test/network/testutils/utils.go\" } }"
let VimuxRunnerIndex = "%99"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/master/GoDCApp
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +348 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Network/src/network/usecase/onboarding.go
badd +194 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Network/src/network/usecase/discovery.go
badd +303 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Network/src/network/usecase/correlator/device_correlator.go
badd +57 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/functional/usecase/device_onboarding_test.go
badd +247 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/functional/usecase/device_discovery_test.go
badd +127 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/functional/usecase/device_location_change_test.go
badd +55 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/testutils/mocked_location.go
badd +44 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Common/src/domain/models/inferred/managed_device.go
badd +99 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/testutils/mocked_scheduler.go
badd +20 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/config/constants_dev.go
badd +57 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/testutils/functional_utils.go
badd +46 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Common/src/domain/models/network/device_connection_detail.go
badd +191 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/config/constants_device_list.go
badd +323 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/testutils/utils.go
badd +137 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/functional/usecase/collector/mlag_collector_test.go
badd +48 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Network/src/network/infra/initializer.go
badd +155 ~/.go/pkg/mod/github.com/stretchr/testify@v1.10.0/require/require.go
badd +36 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Common/src/gateway/database/generic_operations.go
badd +1 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Common/src/infra/apperrors/nvoerror.go
badd +18 ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Common/src/infra/utils/error_constants.go
argglobal
%argdel
edit ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Network/src/network/usecase/correlator/device_correlator.go
tcd ~/workspace/badaniya/NVO-6193/GoDCApp/NVO
argglobal
balt ~/workspace/badaniya/NVO-6193/GoDCApp/NVO/Test/src/test/network/functional/usecase/device_discovery_test.go
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
let s:l = 305 - ((21 * winheight(0) + 28) / 56)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 305
normal! 0107|
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
