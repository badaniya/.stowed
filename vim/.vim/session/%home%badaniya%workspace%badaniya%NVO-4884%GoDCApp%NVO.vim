let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/efa-client/infra/Version.go\" }, { name = \"Common/src/perfmonitorclient/go.mod\" }, { name = \"System/src/system/gateway/common_perfmon_service_adapter.go\" }, { name = \"Common/src/perfmonitorclient/swagger/client.go\" }, { name = \"Common/src/perfmonitorclient/swagger/.swagger-codegen/VERSION\" }, { name = \"~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/fabricclient/go.mod\" }, { name = \"~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/fabricclient/swagger/client.go\" }, { name = \"~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/efa-client/main.go\" }, { name = \"~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/efa-client/go.mod\" }, { name = \"System/src/system/go.mod\" }, { name = \"Common/src/perfmonitorclient/swagger/model_metric_data_request.go\" }, { name = \"Common/src/perfmonitorclient/swagger/api_metric_data.go\" }, { name = \"Test/src/test/system/unit/grpc_portstats/grpc_portstats_test.go\" }, { name = \"System/src/system/usecase/physical_link.go\" }, { name = \"Test/src/test/system/unit/perfmon_stats/perfmon_stats_test.go\" }, { name = \"Test/src/test/system/testutils/utils.go\" }, { name = \"Test/src/test/network/testutils/utils.go\" }, { name = \"Test/src/test/system/unit/mock/mock_common_perfmon_service_adapter.go\" }, { name = \"Test/src/test/system/unit/mock/mock_external_grpc_adapter.go\" }, { name = \"Common/src/domain/models/inferred/port.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-4884/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +12 Common/src/perfmonitorclient/go.mod
badd +59 System/src/system/gateway/common_perfmon_service_adapter.go
badd +71 System/src/system/go.mod
badd +405 Test/src/test/system/unit/perfmon_stats/perfmon_stats_test.go
badd +1 ~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/efa-client/infra/Version.go
badd +39 ~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/efa-client/go.mod
badd +1 ~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/fabricclient/go.mod
badd +239 Common/src/perfmonitorclient/swagger/client.go
badd +88 Common/src/perfmonitorclient/swagger/api_metric_data.go
badd +1 Common/src/perfmonitorclient/swagger/.swagger-codegen/VERSION
badd +1 ~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/fabricclient/swagger/client.go
badd +61 ~/workspace/badaniya/NVO-4884/GoDCApp/XCO/GoCommon/src/efa-client/main.go
badd +13 ~/workspace/badaniya/NVO-4884/GoDCApp/NVO/Common/src/perfmonitorclient/swagger/model_metric_data_request.go
badd +635 ~/workspace/badaniya/NVO-4884/GoDCApp/NVO/Test/src/test/system/unit/grpc_portstats/grpc_portstats_test.go
badd +381 ~/workspace/badaniya/NVO-4884/GoDCApp/NVO/System/src/system/usecase/physical_link.go
badd +187 ~/workspace/badaniya/NVO-4884/GoDCApp/NVO/Test/src/test/system/testutils/utils.go
badd +332 ~/workspace/badaniya/NVO-4884/GoDCApp/NVO/Test/src/test/network/testutils/utils.go
badd +29 ~/workspace/badaniya/NVO-4884/GoDCApp/NVO/Test/src/test/system/unit/mock/mock_common_perfmon_service_adapter.go
badd +60 ~/workspace/badaniya/NVO-4884/GoDCApp/NVO/Test/src/test/system/unit/mock/mock_external_grpc_adapter.go
badd +52 ~/workspace/badaniya/NVO-4884/GoDCApp/NVO/Common/src/domain/models/inferred/port.go
argglobal
%argdel
edit Common/src/perfmonitorclient/swagger/api_metric_data.go
argglobal
balt System/src/system/gateway/common_perfmon_service_adapter.go
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
let s:l = 88 - ((55 * winheight(0) + 37) / 74)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 88
normal! 09|
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
