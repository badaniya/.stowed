let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"System/src/system/main.go\" }, { name = \"System/src/system/usecase/physical_link.go\" }, { name = \"Common/src/domain/models/network/port.go\" }, { name = \"Common/src/domain/models/inferred/port.go\" }, { name = \"Common/src/domain/models/inferred/interface.go\" }, { name = \"Common/src/domain/models/inferred/physical_link.go\" }, { name = \"Common/src/infra/rest/generated/server/go/model_edge_data.go\" }, { name = \"Common/src/infra/rest/generated/server/go/model_physical_edge_detail.go\" }, { name = \"System/src/system/infra/rest/openapi/handler/topology.go\" }, { name = \"System/src/system/infra/events/websocket_events.go\" }, { name = \"Common/src/infra/rest/generated/server/go/model_topology.go\" }, { name = \"Common/src/infra/rest/generated/server/go/model_edge.go\" }, { name = \"Common/src/infra/rest/generated/server/go/model_attribute_text.go\" }, { name = \"Common/etc/database/views/schema/create_views.sql\" }, { name = \"Test/src/test/Integration/mock/db_mock_test.go\" }, { name = \"Test/src/test/Common/unit/testutils/integration_setup.go\" }, { name = \"System/src/system/usecase/device.go\" }, { name = \"Common/src/infra/marshal/topology_edge.go\" }, { name = \"Common/src/gateway/usecase/group.go\" }, { name = \"Common/src/domain/models/network/lldp_neighbor_state.go\" }, { name = \"Common/src/domain/models/network/lldp_neighbor_ztf_tunnel_group.go\" }, { name = \"Common/src/domain/models/network/lldp_neighbor_ztf.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/24.3.0/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +1 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/System/src/system/main.go
badd +86 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/System/src/system/usecase/physical_link.go
badd +58 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/System/src/system/usecase/device.go
badd +323 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/domain/models/network/port.go
badd +12 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/domain/models/inferred/port.go
badd +27 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/domain/models/inferred/interface.go
badd +1402 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/infra/marshal/topology_edge.go
badd +15 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/domain/models/inferred/physical_link.go
badd +18 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/infra/rest/generated/server/go/model_edge_data.go
badd +19 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/infra/rest/generated/server/go/model_physical_edge_detail.go
badd +145 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/System/src/system/infra/rest/openapi/handler/topology.go
badd +266 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/System/src/system/infra/events/websocket_events.go
badd +16 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/infra/rest/generated/server/go/model_topology.go
badd +12 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/infra/rest/generated/server/go/model_edge.go
badd +12 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/infra/rest/generated/server/go/model_attribute_text.go
badd +134 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/etc/database/views/schema/create_views.sql
badd +104 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Test/src/test/Integration/mock/db_mock_test.go
badd +1075 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Test/src/test/Common/unit/testutils/integration_setup.go
badd +59 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/gateway/usecase/group.go
badd +29 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/domain/models/network/lldp_neighbor_state.go
badd +18 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/domain/models/network/lldp_neighbor_ztf_tunnel_group.go
badd +13 ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Common/src/domain/models/network/lldp_neighbor_ztf.go
argglobal
%argdel
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt ~/workspace/badaniya/24.3.0/GoDCApp/NVO/Test/src/test/Common/unit/testutils/integration_setup.go
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
