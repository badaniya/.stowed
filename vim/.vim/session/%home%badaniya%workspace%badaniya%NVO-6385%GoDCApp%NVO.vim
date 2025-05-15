let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Network/src/network/usecase/discovery.go\" }, { name = \"Network/src/network/usecase/discovery_wireless.go\" }, { name = \"Network/src/network/usecase/collector/poe_power_collector.go\" }, { name = \"Network/src/network/usecase/collector/utils.go\" }, { name = \"Network/src/network/usecase/collector/system_collector.go\" }, { name = \"Network/src/network/usecase/collector/lldp_collector.go\" }, { name = \"Common/src/infra/eventing/events/model/events/device_onboard_event.go\" }, { name = \"Common/src/domain/models/network/device_connection_detail.go\" }, { name = \"Network/src/network/usecase/onboarding.go\" }, { name = \"Network/src/network/infra/events/internal_handler.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6385/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +5 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/usecase/discovery.go
badd +389 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/usecase/discovery_wireless.go
badd +60 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/usecase/collector/poe_power_collector.go
badd +65 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/usecase/collector/system_collector.go
badd +1 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/usecase/collector/lldp_collector.go
badd +44 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/usecase/collector/utils.go
badd +104 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Common/src/infra/eventing/events/model/events/device_onboard_event.go
badd +46 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Common/src/domain/models/network/device_connection_detail.go
badd +188 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/usecase/onboarding.go
badd +205 ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/infra/events/internal_handler.go
argglobal
%argdel
edit ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/usecase/collector/lldp_collector.go
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
file neo-tree\ filesystem\ \[1]
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
balt ~/workspace/badaniya/NVO-6385/GoDCApp/NVO/Network/src/network/usecase/collector/utils.go
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
let s:l = 61 - ((60 * winheight(0) + 35) / 71)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 61
normal! 0
wincmd w
2wincmd w
wincmd =
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
