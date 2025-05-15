let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Network/src/network/main.go\" }, { name = \"Network/src/network/usecase/collector/system_collector.go\" }, { name = \"~/.go/pkg/mod/github.extremenetworks.com/!engineering/!platform!common!models/!config!state/src/configstate@v0.0.0-20250501010414-6be7af9f8920/domain/models/asset/AssetDevice.go\" }, { name = \"Network/src/network/usecase/onboarding.go\" }, { name = \"Network/src/network/usecase/discovery.go\" }, { name = \"Network/src/network/infra/events/internal_handler.go\" }, { name = \"Network/src/network/usecase/ap_device_data_collection_event.go\" }, { name = \"Network/src/network/usecase/config_orchestrator.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-TEST/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +125 Network/src/network/main.go
badd +99 ~/workspace/badaniya/NVO-TEST/GoDCApp/NVO/Network/src/network/usecase/collector/system_collector.go
badd +22 ~/.go/pkg/mod/github.extremenetworks.com/\!engineering/\!platform\!common\!models/\!config\!state/src/configstate@v0.0.0-20250501010414-6be7af9f8920/domain/models/asset/AssetDevice.go
badd +300 Network/src/network/usecase/onboarding.go
badd +1004 ~/workspace/badaniya/NVO-TEST/GoDCApp/NVO/Network/src/network/usecase/discovery.go
badd +1683 Network/src/network/usecase/config_orchestrator.go
badd +228 Network/src/network/infra/events/internal_handler.go
badd +93 Network/src/network/usecase/ap_device_data_collection_event.go
argglobal
%argdel
edit Network/src/network/usecase/onboarding.go
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ~/workspace/badaniya/NVO-TEST/GoDCApp/NVO/Network/src/network/usecase/discovery.go
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
let s:l = 300 - ((25 * winheight(0) + 29) / 58)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 300
normal! 0
tabnext 1
if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=1
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
