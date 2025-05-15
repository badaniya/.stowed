let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Network/src/network/infra/events/internal_handler.go\" }, { name = \"Common/src/infra/eventing/events/model/events/telegraf_events.go\" }, { name = \"Network/src/network/usecase/telegraf_event.go\" }, { name = \"Common/src/infra/grpc/grpcinfra.go\" }, { name = \"Network/src/network/usecase/schedule_event.go\" }, { name = \"Network/src/network/usecase/telegraf_cache.go\" }, { name = \"Common/src/infra/caching/cache.go\" }, { name = \"Network/src/network/usecase/telegraf.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-5008/GoDCApp
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +252 NVO/Network/src/network/usecase/telegraf.go
badd +1 NVO/Network/src/network/infra/events/internal_handler.go
badd +519 NVO/Common/src/infra/eventing/events/model/events/telegraf_events.go
badd +447 NVO/Network/src/network/usecase/telegraf_cache.go
badd +138 NVO/Common/src/infra/caching/cache.go
badd +269 NVO/Network/src/network/usecase/telegraf_event.go
badd +17 NVO/Common/src/infra/grpc/grpcinfra.go
badd +76 NVO/Network/src/network/usecase/schedule_event.go
argglobal
%argdel
tcd ~/workspace/badaniya/NVO-5008/GoDCApp/NVO
argglobal
enew
file ~/workspace/badaniya/NVO-5008/GoDCApp/neo-tree\ filesystem\ \[1]
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
