let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Db_ui_buffer_name_generator =  0 
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let Db_ui_table_name_sorter =  0 
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all ./Test/src/test/network/unit/usecase/devicediscovery/...'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all ./Test/src/test/network/unit/usecase/devicediscovery/..."
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Network/src/network/usecase/onboarding.go\", pinned = true }, { name = \"Network/src/network/usecase/discovery.go\", pinned = true }, { name = \"Common/src/domain/models/ccs/inferred/enum_map.go\" }, { name = \"Common/src/domain/models/ccs/utils/db_models_enum_conversions.go\" }, { name = \"Network/src/network/infra/rest/openapi/handler/refresh.go\" }, { name = \"Network/src/network/usecase/refresh.go\" }, { name = \"Test/src/test/runonce/unit/location_hierarchy/hierarchy_data_multi.txt\" }, { name = \"Common/src/infra/eventing/events/model/constants.go\" }, { name = \"Edge/src/edge/usecase/discovery.go\" }, { name = \"Network/src/network/infra/events/external_handler.go\" }, { name = \"Network/src/network/main.go\" }, { name = \"Common/src/infra/messaging/messaging_interface.go\" }, { name = \"Common/src/infra/messaging/connector.go\" }, { name = \"Network/src/network/infra/events/internal_handler.go\" }, { name = \"Network/src/network/usecase/config_orchestrator.go\" } }"
let VimuxRunnerIndex = "%5"
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
badd +222 Network/src/network/usecase/onboarding.go
badd +74 Network/src/network/usecase/discovery.go
badd +1817 Common/src/domain/models/ccs/utils/db_models_enum_conversions.go
badd +60 Common/src/domain/models/ccs/inferred/enum_map.go
badd +65 Network/src/network/usecase/refresh.go
badd +1 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Network/src/network/infra/rest/openapi/handler/refresh.go
badd +5 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Test/src/test/runonce/unit/location_hierarchy/hierarchy_data_multi.txt
badd +161 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Common/src/infra/eventing/events/model/constants.go
badd +238 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Edge/src/edge/usecase/discovery.go
badd +216 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Network/src/network/main.go
badd +88 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Network/src/network/infra/events/external_handler.go
badd +27 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Common/src/infra/messaging/messaging_interface.go
badd +279 ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Common/src/infra/messaging/connector.go
badd +244 Network/src/network/infra/events/internal_handler.go
badd +1558 Network/src/network/usecase/config_orchestrator.go
argglobal
%argdel
edit ~/workspace/badaniya/NVO-5930/GoDCApp/NVO/Network/src/network/infra/rest/openapi/handler/refresh.go
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt Network/src/network/usecase/refresh.go
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
let s:l = 49 - ((41 * winheight(0) + 36) / 73)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 49
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
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
