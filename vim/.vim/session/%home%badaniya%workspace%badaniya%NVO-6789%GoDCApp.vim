let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Network/src/network/usecase/discovery.go\" }, { name = \"Common/src/tagclientapi/taggingFetch.go\" }, { name = \"Common/src/tagclientapi/tagging.go\" }, { name = \"Edge/src/edge/usecase/correlator/tag_utils.go\" }, { name = \"System/src/system/infra/rest/openapi/handler/tags.go\" }, { name = \"System/src/system/infra/rest/routers.go\" }, { name = \"Common/src/gateway/database/tags/tags.go\" }, { name = \"Common/src/infra/constants/common.go\" }, { name = \"Common/src/domain/models/ccs/inferred/InferredDevice.go\" }, { name = \"Common/src/tagclient/swagger/model_entity_request.go\" }, { name = \"Common/src/domain/utils/tag_utilities.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6789/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +478 Network/src/network/usecase/discovery.go
badd +567 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/Common/src/domain/utils/tag_utilities.go
badd +15 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/Common/src/tagclientapi/taggingFetch.go
badd +294 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/Common/src/tagclientapi/tagging.go
badd +228 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/Edge/src/edge/usecase/correlator/tag_utils.go
badd +288 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/System/src/system/infra/rest/openapi/handler/tags.go
badd +260 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/System/src/system/infra/rest/routers.go
badd +123 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/Common/src/gateway/database/tags/tags.go
badd +73 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/Common/src/infra/constants/common.go
badd +25 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/Common/src/domain/models/ccs/inferred/InferredDevice.go
badd +20 ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/Common/src/tagclient/swagger/model_entity_request.go
argglobal
%argdel
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt ~/workspace/badaniya/NVO-6789/GoDCApp/NVO/Common/src/domain/utils/tag_utilities.go
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
