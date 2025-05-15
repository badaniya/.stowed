let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/workspace/badaniya/NVO-6555/PlatformServices/ConfigState/src/configstate/domain/models/inferred/InferredPort.go\" }, { name = \"Network/src/network/usecase/discovery.go\" }, { name = \"Network/src/network/usecase/gateway_interactor.go\" }, { name = \"Network/src/network/infra/initializer.go\" }, { name = \"Network/src/network/gateway/device_adapter_factory.go\" }, { name = \"Common/src/domain/models/ccs/asset/AssetDeviceConnectionDetail.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6555/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +23 ~/workspace/badaniya/NVO-6555/PlatformServices/ConfigState/src/configstate/domain/models/inferred/InferredPort.go
badd +66 Network/src/network/infra/initializer.go
badd +33 Network/src/network/usecase/gateway_interactor.go
badd +181 Network/src/network/usecase/discovery.go
badd +26 ~/workspace/badaniya/NVO-6555/GoDCApp/NVO/Network/src/network/gateway/device_adapter_factory.go
badd +22 ~/workspace/badaniya/NVO-6555/GoDCApp/NVO/Common/src/domain/models/ccs/asset/AssetDeviceConnectionDetail.go
argglobal
%argdel
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
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
