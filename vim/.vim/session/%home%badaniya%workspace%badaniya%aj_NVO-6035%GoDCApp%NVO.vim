let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestRunOnce_GetLocationHierarchyWithMultiCreateAsOwnerIDZero$'\\'' ./Test/src/test/runonce/unit/location_hierarchy'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestRunOnce_GetLocationHierarchyWithMultiCreateAsOwnerIDZero$' ./Test/src/test/runonce/unit/location_hierarchy"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_test.go\", pinned = true }, { name = \"Test/src/test/runonce/unit/location_inconsistency/location_inconsistency_test.go\", pinned = true }, { name = \"Common/src/gateway/usecase/location_hierarchy.go\", pinned = true }, { name = \"RunOnce/src/runonce/usecase/location_consistency.go\", pinned = true }, { name = \"Common/src/gateway/database/read_options.go\" }, { name = \"Common/src/domain/utils/tag_utilities.go\" }, { name = \"Edge/src/edge/infra/database/AssetIsisL3Vsn.go\" }, { name = \"Common/src/gateway/database/tags/tags.go\" }, { name = \"Common/src/domain/models/inferred/group.go\" }, { name = \"Common/src/gateway/database/generic_operations.go\" }, { name = \"Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_main_test.go\" }, { name = \"Test/src/test/network/unit/usecase/correlator/correlator_main_test.go\" }, { name = \"Test/src/test/network/testutils/utils.go\" }, { name = \"Test/src/test/runonce/testutils/utils.go\" }, { name = \"RunOnce/src/runonce/infra/configs/constants.go\" }, { name = \"Common/src/infra/configs/application.go\" }, { name = \"RunOnce/src/runonce/infra/configs/setup.go\" } }"
let VimuxRunnerIndex = "%84"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +30 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/RunOnce/src/runonce/usecase/location_consistency.go
badd +88 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Common/src/gateway/usecase/location_hierarchy.go
badd +13 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Common/src/domain/models/inferred/group.go
badd +10 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_test.go
badd +119 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Test/src/test/runonce/unit/location_inconsistency/location_inconsistency_test.go
badd +73 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Common/src/gateway/database/read_options.go
badd +1 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Common/src/gateway/database/generic_operations.go
badd +92 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Common/src/domain/utils/tag_utilities.go
badd +165 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Common/src/gateway/database/tags/tags.go
badd +23 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Edge/src/edge/infra/database/AssetIsisL3Vsn.go
badd +21 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_main_test.go
badd +30 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Test/src/test/network/unit/usecase/correlator/correlator_main_test.go
badd +491 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Test/src/test/network/testutils/utils.go
badd +218 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Test/src/test/runonce/testutils/utils.go
badd +34 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/RunOnce/src/runonce/infra/configs/constants.go
badd +324 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Common/src/infra/configs/application.go
badd +23 ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/RunOnce/src/runonce/infra/configs/setup.go
argglobal
%argdel
edit ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Common/src/gateway/database/generic_operations.go
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ~/workspace/badaniya/aj_NVO-6035/GoDCApp/NVO/Common/src/gateway/database/read_options.go
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
let s:l = 1 - ((0 * winheight(0) + 22) / 44)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1
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
