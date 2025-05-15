let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"GoSwitch/src/goswitch/test/switchinfowireless_test.go\" }, { name = \"GoSwitch/src/goswitch/device/platforms/accesspoint/accessPointConnector.go\" }, { name = \"GoSwitch/src/goswitch/device/platforms/accesspoint/base/SwitchDetailsAction.go\" }, { name = \"GoSwitch/src/goswitch/model/switchinfo.go\" } }"
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''Test_SwitchDetailsWireless_Get_State$'\\'' ./GoSwitch/src/goswitch/test'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'Test_SwitchDetailsWireless_Get_State$' ./GoSwitch/src/goswitch/test"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let VimuxRunnerIndex = "0"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-5598/GoDCApp
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +29 ~/workspace/badaniya/NVO-5598/GoDCApp/GoSwitch/src/goswitch/test/switchinfowireless_test.go
badd +19 ~/workspace/badaniya/NVO-5598/GoDCApp/GoSwitch/src/goswitch/device/platforms/accesspoint/accessPointConnector.go
badd +111 ~/workspace/badaniya/NVO-5598/GoDCApp/GoSwitch/src/goswitch/device/platforms/accesspoint/base/SwitchDetailsAction.go
badd +24 ~/workspace/badaniya/NVO-5598/GoDCApp/GoSwitch/src/goswitch/model/switchinfo.go
argglobal
%argdel
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
enew
file neo-tree\ filesystem\ \[1]
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
