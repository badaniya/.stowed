let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"System/src/system/main.go\" }, { name = \"System/src/system/usecase/topology.go\" }, { name = \"Common/src/infra/marshal/topology_edge.go\" }, { name = \"Common/src/domain/models/inferred/group.go\" }, { name = \"Common/src/domain/models/inferred/topology.go\" }, { name = \"Common/src/infra/apperrors/constants.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6079/GoDCApp
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +38 NVO/System/src/system/main.go
badd +64 NVO/System/src/system/usecase/topology.go
badd +1405 NVO/Common/src/infra/marshal/topology_edge.go
badd +21 NVO/Common/src/domain/models/inferred/group.go
badd +4 NVO/Common/src/domain/models/inferred/topology.go
badd +22 NVO/Common/src/infra/apperrors/constants.go
argglobal
%argdel
tcd ~/workspace/badaniya/NVO-6079/GoDCApp/NVO
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
let g:this_session = v:this_session
let g:this_obsession = v:this_session
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
