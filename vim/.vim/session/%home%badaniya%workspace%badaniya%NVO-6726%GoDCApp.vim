let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Common/src/infra/constants/common.go\" }, { name = \"Common/src/tagclientapi/tagging.go\" }, { name = \"Common/src/infra/apperrors/constants.go\" }, { name = \"Common/src/tagclient/swagger/api_tags.go\" }, { name = \"Common/src/tagclient/swagger/client.go\" }, { name = \"Common/src/tagclient/swagger/model_error_response.go\" }, { name = \"Common/src/tagclient/swagger/model_create_tag_response.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6726/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +118 Common/src/infra/constants/common.go
badd +162 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Common/src/tagclientapi/tagging.go
badd +107 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Common/src/infra/apperrors/constants.go
badd +35 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Common/src/tagclient/swagger/api_tags.go
badd +473 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Common/src/tagclient/swagger/client.go
badd +13 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Common/src/tagclient/swagger/model_error_response.go
badd +12 ~/workspace/badaniya/NVO-6726/GoDCApp/NVO/Common/src/tagclient/swagger/model_create_tag_response.go
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
