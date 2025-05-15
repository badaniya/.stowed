let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"RunOnce/src/runonce/main.go\" }, { name = \"RunOnce/src/runonce/utils/fetch_location_hierarchy.go\" }, { name = \"Common/src/gateway/usecase/location_hierarchy.go\" }, { name = \"Common/src/interactorinterface/external_hive_adapter.go\" }, { name = \"Common/src/gateway/usecase/external_hive_adapter.go\" }, { name = \"Common/src/gateway/usecase/location_client.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-5995/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +119 RunOnce/src/runonce/main.go
badd +49 ~/workspace/badaniya/NVO-5995/GoDCApp/NVO/RunOnce/src/runonce/utils/fetch_location_hierarchy.go
badd +48 ~/workspace/badaniya/NVO-5995/GoDCApp/NVO/Common/src/gateway/usecase/location_hierarchy.go
badd +23 ~/workspace/badaniya/NVO-5995/GoDCApp/NVO/Common/src/interactorinterface/external_hive_adapter.go
badd +39 ~/workspace/badaniya/NVO-5995/GoDCApp/NVO/Common/src/gateway/usecase/external_hive_adapter.go
badd +31 ~/workspace/badaniya/NVO-5995/GoDCApp/NVO/Common/src/gateway/usecase/location_client.go
argglobal
%argdel
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt RunOnce/src/runonce/main.go
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
