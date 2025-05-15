let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/workspace/badaniya/NVO-4607/GoDCApp/NVO\" }, { name = \"~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/adapter/InletRestAdapter.go\" }, { name = \"~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/client/Restclient.go\" }, { name = \"~/.go/pkg/mod/golang.org/toolchain@v0.0.1-go1.23.3.linux-amd64/src/net/http/request.go\" }, { name = \"~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/adapter/SwitchRestAdapter.go\" }, { name = \"~/.go/pkg/mod/golang.org/toolchain@v0.0.1-go1.23.3.linux-amd64/src/net/http/client.go\" }, { name = \"~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/adapter/AdapterConfig.go\" }, { name = \"~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/session/Repository.go\" }, { name = \"~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/deviceadapter.go\" }, { name = \"Network/src/network/gateway/device_adapter_factory.go\" }, { name = \"Network/src/network/usecase/config_orchestrator.go\" }, { name = \"Network/src/network/usecase/gateway_interactor.go\" }, { name = \"Common/src/domain/models/network/device_connection_detail.go\" }, { name = \"Test/src/test/network/functional/usecase/collector/collector_main_test.go\" }, { name = \"Test/src/test/network/unit/usecase/collector/system_test.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-4607/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +107 ~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/adapter/InletRestAdapter.go
badd +195 ~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/adapter/SwitchRestAdapter.go
badd +269 ~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/client/Restclient.go
badd +872 ~/.go/pkg/mod/golang.org/toolchain@v0.0.1-go1.23.3.linux-amd64/src/net/http/request.go
badd +855 ~/.go/pkg/mod/golang.org/toolchain@v0.0.1-go1.23.3.linux-amd64/src/net/http/client.go
badd +98 ~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/adapter/AdapterConfig.go
badd +83 ~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/session/Repository.go
badd +270 ~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/deviceadapter.go
badd +18 Network/src/network/gateway/device_adapter_factory.go
badd +65 Network/src/network/usecase/config_orchestrator.go
badd +31 Network/src/network/usecase/gateway_interactor.go
badd +28 ~/workspace/badaniya/NVO-4607/GoDCApp/NVO/Common/src/domain/models/network/device_connection_detail.go
badd +110 Test/src/test/network/functional/usecase/collector/collector_main_test.go
badd +1219 Test/src/test/network/unit/usecase/collector/system_test.go
argglobal
%argdel
tabnew +setlocal\ bufhidden=wipe
tabrewind
edit Network/src/network/usecase/gateway_interactor.go
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe '1resize ' . ((&lines * 63 + 38) / 76)
exe 'vert 1resize ' . ((&columns * 40 + 147) / 294)
exe '2resize ' . ((&lines * 63 + 38) / 76)
exe 'vert 2resize ' . ((&columns * 198 + 147) / 294)
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt ~/workspace/badaniya/NVO-4607/GoDCApp/GoSwitch/src/goswitch/device/client/Restclient.go
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
wincmd w
argglobal
balt ~/workspace/badaniya/NVO-4607/GoDCApp/NVO/Common/src/domain/models/network/device_connection_detail.go
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
let s:l = 31 - ((30 * winheight(0) + 31) / 63)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 31
normal! 023|
wincmd w
exe '1resize ' . ((&lines * 63 + 38) / 76)
exe 'vert 1resize ' . ((&columns * 40 + 147) / 294)
exe '2resize ' . ((&lines * 63 + 38) / 76)
exe 'vert 2resize ' . ((&columns * 198 + 147) / 294)
tabnext
edit Test/src/test/network/unit/usecase/collector/system_test.go
let s:save_splitbelow = &splitbelow
let s:save_splitright = &splitright
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
let &splitbelow = s:save_splitbelow
let &splitright = s:save_splitright
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
wincmd =
argglobal
enew
file neo-tree\ filesystem\ \[2]
balt Network/src/network/usecase/config_orchestrator.go
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
wincmd w
argglobal
balt Network/src/network/usecase/config_orchestrator.go
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
let s:l = 1159 - ((13 * winheight(0) + 37) / 74)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1159
normal! 0
wincmd w
2wincmd w
wincmd =
tabnext 2
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
