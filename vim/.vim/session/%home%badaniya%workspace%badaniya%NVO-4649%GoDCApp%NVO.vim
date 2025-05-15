let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/workspace/badaniya/NVO-4649/GoDCApp/GoSwitch/src/goswitch/device/platforms/voss/VosConnector.go\" }, { name = \"Test/src/test/network/functional/usecase/device_onboarding_test.go\" }, { name = \"Test/src/test/network/config/constants_dev.go\" }, { name = \"Test/src/test/network/functional/usecase/collector/capabilities_collector_test.go\" } }"
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''Test_DeviceOnboardingVoss$'\\'' ./Test/src/test/network/functional/usecase'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'Test_DeviceOnboardingVoss$' ./Test/src/test/network/functional/usecase"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let VimuxRunnerIndex = "%46"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-4649/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +41 ~/workspace/badaniya/NVO-4649/GoDCApp/GoSwitch/src/goswitch/device/platforms/voss/VosConnector.go
badd +1 Test/src/test/network/functional/usecase/device_onboarding_test.go
badd +28 ~/workspace/badaniya/NVO-4649/GoDCApp/NVO/Test/src/test/network/config/constants_dev.go
badd +31 ~/workspace/badaniya/NVO-4649/GoDCApp/NVO/Test/src/test/network/functional/usecase/collector/capabilities_collector_test.go
argglobal
%argdel
edit Test/src/test/network/functional/usecase/device_onboarding_test.go
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ~/workspace/badaniya/NVO-4649/GoDCApp/NVO/Test/src/test/network/functional/usecase/collector/capabilities_collector_test.go
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
let s:l = 238 - ((30 * winheight(0) + 24) / 48)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 238
normal! 040|
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
let g:this_session = v:this_session
let g:this_obsession = v:this_session
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
