let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestGetDevicePhysicalLink_LagWithDevice1AndDevice2SwappedLagMembers$'\\'' ./Test/src/test/system/unit/usecase'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestGetDevicePhysicalLink_LagWithDevice1AndDevice2SwappedLagMembers$' ./Test/src/test/system/unit/usecase"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/workspace/badaniya/NVO-6145/GoDCApp/NVO/Test/src/test/system/unit/usecase/get_device_physical_link_test.go\", pinned = true }, { name = \"~/workspace/badaniya/NVO-6145/GoDCApp/NVO/Test/src/test/system/testutils/domain_utils.go\", pinned = true }, { name = \"~/workspace/badaniya/NVO-6145/GoDCApp/NVO/System/src/system/infra/rest/openapi/handler/topology.go\", pinned = true }, { name = \"~/workspace/badaniya/NVO-6145/GoDCApp/NVO/Common/src/infra/marshal/topology_edge.go\", pinned = true }, { name = \"~/workspace/badaniya/NVO-6145/GoDCApp/NVO/System/src/system/infra/rest/openapi/handler/physical_link.go\" }, { name = \"~/workspace/badaniya/NVO-6145/GoDCApp/NVO/System/src/system/infra/rest/openapi/handler/util.go\" }, { name = \"~/workspace/badaniya/NVO-6145/GoDCApp/NVO/System/src/system/usecase/physical_link.go\" } }"
let VimuxRunnerIndex = "%91"
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
badd +68 Test/src/test/system/unit/usecase/get_device_physical_link_test.go
badd +95 Test/src/test/system/testutils/domain_utils.go
badd +566 System/src/system/infra/rest/openapi/handler/physical_link.go
badd +864 System/src/system/infra/rest/openapi/handler/topology.go
badd +719 Common/src/infra/marshal/topology_edge.go
badd +356 System/src/system/usecase/physical_link.go
badd +16 ~/workspace/badaniya/NVO-6145/GoDCApp/NVO/System/src/system/infra/rest/openapi/handler/util.go
argglobal
%argdel
edit Test/src/test/system/unit/usecase/get_device_physical_link_test.go
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt System/src/system/infra/rest/openapi/handler/topology.go
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
let s:l = 68 - ((10 * winheight(0) + 26) / 53)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 68
normal! 050|
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
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
