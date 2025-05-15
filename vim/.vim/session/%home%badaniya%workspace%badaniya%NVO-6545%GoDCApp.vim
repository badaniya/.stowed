let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_test.go\", pinned = true }, { name = \"Common/src/gateway/usecase/group.go\", pinned = true }, { name = \"Network/src/network/infra/utils/correlator_utilities.go\" }, { name = \"Network/src/network/usecase/correlator/physical_link_correlator.go\" }, { name = \"Common/src/gateway/usecase/location_hierarchy.go\" }, { name = \"RunOnce/src/runonce/usecase/location_consistency.go\" } }"
let VimuxRunnerIndex = "%5"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestRunOnce_CreateLocationHierarchy$'\\'' ./Test/src/test/runonce/unit/location_hierarchy'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestRunOnce_CreateLocationHierarchy$' ./Test/src/test/runonce/unit/location_hierarchy"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6545/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +5 ~/workspace/badaniya/NVO-6545/GoDCApp/NVO/Common/src/gateway/usecase/location_hierarchy.go
badd +67 ~/workspace/badaniya/NVO-6545/GoDCApp/NVO/Common/src/gateway/usecase/group.go
badd +195 ~/workspace/badaniya/NVO-6545/GoDCApp/NVO/Test/src/test/runonce/unit/location_hierarchy/location_hierarchy_test.go
badd +334 ~/workspace/badaniya/NVO-6545/GoDCApp/NVO/RunOnce/src/runonce/usecase/location_consistency.go
badd +20 ~/workspace/badaniya/NVO-6545/GoDCApp/NVO/Network/src/network/infra/utils/correlator_utilities.go
badd +298 ~/workspace/badaniya/NVO-6545/GoDCApp/NVO/Network/src/network/usecase/correlator/physical_link_correlator.go
argglobal
%argdel
edit ~/workspace/badaniya/NVO-6545/GoDCApp/NVO/RunOnce/src/runonce/usecase/location_consistency.go
argglobal
balt ~/workspace/badaniya/NVO-6545/GoDCApp/NVO/Common/src/gateway/usecase/location_hierarchy.go
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
let s:l = 334 - ((18 * winheight(0) + 23) / 46)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 334
normal! 067|
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
