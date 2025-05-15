let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestDeviceAdapterInlets$'\\'' ./GoSwitch/src/goswitch/test/device'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestDeviceAdapterInlets$' ./GoSwitch/src/goswitch/test/device"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"GoSwitch/src/goswitch/device/session/Repository.go\" }, { name = \"GoSwitch/src/goswitch/domain/adapter.go\" }, { name = \"GoSwitch/src/goswitch/test/device/session/repository_test.go\" }, { name = \"GoSwitch/src/goswitch/test/device/device_adapter_test.go\" }, { name = \"GoSwitch/src/goswitch/device/deviceadapter.go\" } }"
let VimuxRunnerIndex = "%62"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/24.2.1/GoDCApp
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +1 GoSwitch/src/goswitch/device/session/Repository.go
badd +58 ~/workspace/badaniya/24.2.1/GoDCApp/GoSwitch/src/goswitch/domain/adapter.go
badd +47 ~/workspace/badaniya/24.2.1/GoDCApp/GoSwitch/src/goswitch/test/device/session/repository_test.go
badd +79 ~/workspace/badaniya/24.2.1/GoDCApp/GoSwitch/src/goswitch/test/device/device_adapter_test.go
badd +382 ~/workspace/badaniya/24.2.1/GoDCApp/GoSwitch/src/goswitch/device/deviceadapter.go
argglobal
%argdel
edit GoSwitch/src/goswitch/device/session/Repository.go
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
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
let s:l = 1 - ((0 * winheight(0) + 20) / 40)
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
