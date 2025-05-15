let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/workspace/badaniya/NVO-4527/GoDCApp\" } }"
let VimuxTmuxCommand = "tmux"
let VimuxPromptString = "Command? "
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestEXOSStackDeviceDiscoveryWithFailover$'\\'' ./Test/src/test/network/functional/usecase'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestEXOSStackDeviceDiscoveryWithFailover$' ./Test/src/test/network/functional/usecase"
let VimuxResetSequence = "C-u"
let VimuxOpenExtraArgs = ""
let VimuxOrientation = "v"
let VimuxRunnerIndex = "%121"
let VimuxRunnerType = "pane"
let SessionLoad =  1 
let VimuxHeight = "20%"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-4527/GoDCApp
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +612 NVO/Network/src/network/usecase/correlator/device_correlator.go
badd +54 GoSwitch/src/goswitch/device/adapter/SwitchSshAdapter.go
badd +11 GoSwitch/src/goswitch/device/client/Sshclient.go
badd +229 NVO/Test/src/test/network/functional/usecase/device_discovery_test.go
badd +411 NVO/Test/src/test/network/functional/usecase/device_onboarding_test.go
badd +73 GoSwitch/src/goswitch/device/client/ClientConfig.go
badd +815 GoSwitch/src/goswitch/device/session/Repository.go
badd +20 /usr/local/go/src/builtin/builtin.go
badd +128 GoSwitch/src/goswitch/device/adapter/AdapterConfig.go
badd +83 ~/.go/pkg/mod/golang.org/x/crypto@v0.25.0/ssh/client.go
badd +328 ~/.go/pkg/mod/golang.org/x/crypto@v0.25.0/ssh/common.go
badd +30 ~/.go/pkg/mod/golang.org/x/crypto@v0.25.0/ssh/transport.go
badd +415 /usr/local/go/src/net/dial.go
badd +114 /usr/local/go/src/net/net.go
badd +56 ~/.go/pkg/mod/golang.org/x/crypto@v0.25.0/ssh/connection.go
badd +137 ~/.go/pkg/mod/golang.org/x/crypto@v0.25.0/ssh/mux.go
badd +632 /usr/local/go/src/bufio/bufio.go
badd +72 ~/workspace/badaniya/NVO-4527/GoDCApp/GoSwitch/src/goswitch/constants/constants.go
argglobal
%argdel
tabnew +setlocal\ bufhidden=wipe
tabnew +setlocal\ bufhidden=wipe
tabrewind
edit ~/.go/pkg/mod/golang.org/x/crypto@v0.25.0/ssh/transport.go
argglobal
balt ~/.go/pkg/mod/golang.org/x/crypto@v0.25.0/ssh/mux.go
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
let s:l = 202 - ((49 * winheight(0) + 36) / 73)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 202
normal! 022|
tabnext
edit GoSwitch/src/goswitch/device/adapter/SwitchSshAdapter.go
argglobal
balt GoSwitch/src/goswitch/device/client/Sshclient.go
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
let s:l = 29 - ((28 * winheight(0) + 36) / 73)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 29
normal! 07|
tabnext
edit GoSwitch/src/goswitch/device/session/Repository.go
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
let s:l = 1 - ((0 * winheight(0) + 36) / 73)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1
normal! 0
tabnext 3
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=1
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
