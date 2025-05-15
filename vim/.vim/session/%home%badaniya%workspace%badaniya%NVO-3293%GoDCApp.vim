let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "q C-u"
let VimuxPromptString = "Command? "
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-3293/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +57 Network/src/network/main.go
badd +640 Network/src/network/usecase/correlator/physical_link_correlator.go
badd +1 Network/src/network/usecase/correlator/fabric_correlator.go
badd +6 Network/src/network/usecase/correlator/device_correlator.go
badd +22 Network/src/network/usecase/correlator/fabric_links_correlator.go
badd +57 Edge/src/edge/usecase/onboarding.go
badd +5 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Network/src/network/gateway/device_adapter.go
badd +94 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Network/src/network/usecase/onboarding.go
badd +755 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Network/src/network/usecase/discovery.go
badd +196 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Network/src/network/usecase/config_db.go
badd +71 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Common/src/infra/eventing/events/model/events/device_discovery_event.go
badd +24 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Edge/src/edge/infra/events/handler.go
badd +15 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Common/src/infra/messaging/messaging_interface.go
badd +317 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Common/src/infra/messaging/connector.go
badd +25 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Common/src/infra/messaging/connectorinterface/connector_interface.go
badd +327 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Common/src/infra/messaging/confluent_kafka/kafka_connector.go
badd +37 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Common/src/infra/eventing/events/model/event_header.go
badd +24 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Common/src/infra/utils/context.go
badd +105 ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Common/src/infra/messaging/confluent_kafka/kafka.go
argglobal
%argdel
edit ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Network/src/network/usecase/config_db.go
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
balt ~/workspace/badaniya/NVO-3293/GoDCApp/NVO/Common/src/infra/eventing/events/model/events/device_discovery_event.go
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
let s:l = 196 - ((23 * winheight(0) + 26) / 53)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 196
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
let g:this_session = v:this_session
let g:this_obsession = v:this_session
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
