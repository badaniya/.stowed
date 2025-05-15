let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Network/src/network/main.go\" }, { name = \"Network/src/network/usecase/correlator/device_correlator.go\" }, { name = \"Network/src/network/usecase/correlator/physical_link_correlator.go\" }, { name = \"Network/src/network/usecase/correlator/fabric_links_correlator.go\" }, { name = \"Common/src/infra/messaging/constants/constants.go\" }, { name = \"Common/src/infra/constants/common.go\" }, { name = \"Common/src/infra/constants/orchestrator_constants.go\" }, { name = \"Common/src/infra/constants/queryParamsConstants.go\" }, { name = \"Common/src/infra/eventing/events/model/constants.go\" }, { name = \"Common/src/domain/models/network/device.go\" }, { name = \"Common/src/infra/constants/context_values.go\" }, { name = \"Network/src/network/usecase/inference_db_cleanup.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-4266/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +28 Network/src/network/main.go
badd +373 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Network/src/network/usecase/correlator/device_correlator.go
badd +30 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Network/src/network/usecase/correlator/physical_link_correlator.go
badd +181 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Network/src/network/usecase/correlator/fabric_links_correlator.go
badd +1 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Common/src/infra/messaging/constants/constants.go
badd +1 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Common/src/infra/constants/common.go
badd +1 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Common/src/infra/constants/orchestrator_constants.go
badd +8 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Common/src/infra/constants/queryParamsConstants.go
badd +112 Common/src/infra/eventing/events/model/constants.go
badd +94 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Common/src/domain/models/network/device.go
badd +26 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Common/src/infra/constants/context_values.go
badd +414 ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Network/src/network/usecase/inference_db_cleanup.go
argglobal
%argdel
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt ~/workspace/badaniya/NVO-4266/GoDCApp/NVO/Network/src/network/usecase/correlator/physical_link_correlator.go
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
