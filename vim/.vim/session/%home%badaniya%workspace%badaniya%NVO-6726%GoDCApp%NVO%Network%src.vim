let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Test/src/test/network/unit/usecase/tagging/device_default_tagging_test.go\", pinned = true }, { name = \"Common/src/tagclientapi/tagging.go\", pinned = true }, { name = \"Common/src/domain/utils/tag_utilities.go\" }, { name = \"System/src/system/usecase/topology.go\" }, { name = \"Common/src/tagclient/swagger/model_tag_info.go\" } }"
let VimuxRunnerIndex = "%399"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestDeviceDefaultTaggingFeatureDuringDeviceOnboard$'\\'' ./Test/src/test/network/unit/usecase/tagging'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestDeviceDefaultTaggingFeatureDuringDeviceOnboard$' ./Test/src/test/network/unit/usecase/tagging"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6726/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +63 Common/src/domain/utils/tag_utilities.go
badd +196 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Common/src/tagclientapi/tagging.go
badd +130 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Test/src/test/network/unit/usecase/tagging/device_default_tagging_test.go
badd +93 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/System/src/system/usecase/topology.go
badd +12 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Common/src/tagclient/swagger/model_tag_info.go
argglobal
%argdel
edit Common/src/domain/utils/tag_utilities.go
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Common/src/tagclientapi/tagging.go
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
let s:l = 63 - ((25 * winheight(0) + 25) / 51)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 63
normal! 021|
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
