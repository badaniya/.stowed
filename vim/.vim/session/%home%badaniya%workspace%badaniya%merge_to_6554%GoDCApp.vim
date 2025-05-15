let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''Test_DeviceOnboardingVoss$'\\'' ./Test/src/test/network/functional/usecase'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'Test_DeviceOnboardingVoss$' ./Test/src/test/network/functional/usecase"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Test/src/test/network/functional/usecase/device_onboarding_test.go\", pinned = true }, { name = \"Network/src/network/usecase/onboarding.go\", pinned = true }, { name = \"Network/src/network/gateway/device_adapter_factory.go\", pinned = true }, { name = \"Network/src/network/usecase/discovery.go\", pinned = true }, { name = \"Network/src/network/usecase/ap_wireless_interface_event.go\" }, { name = \"Network/src/network/usecase/ap_ssid_event.go\" }, { name = \"Common/src/infra/lock/constants.go\" } }"
let VimuxRunnerIndex = "%37"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/merge_to_6554/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +49 Network/src/network/gateway/device_adapter_factory.go
badd +190 Test/src/test/network/functional/usecase/device_onboarding_test.go
badd +85 Network/src/network/usecase/onboarding.go
badd +79 Network/src/network/usecase/discovery.go
badd +128 Network/src/network/usecase/ap_ssid_event.go
badd +118 Network/src/network/usecase/ap_wireless_interface_event.go
badd +34 ~/workspace/badaniya/merge_to_6554/GoDCApp/NVO/Common/src/infra/lock/constants.go
argglobal
%argdel
edit Makefile-context
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ~/workspace/badaniya/merge_to_6554/GoDCApp/NVO/Common/src/infra/lock/constants.go
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
let s:l = 2 - ((1 * winheight(0) + 25) / 50)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 2
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
