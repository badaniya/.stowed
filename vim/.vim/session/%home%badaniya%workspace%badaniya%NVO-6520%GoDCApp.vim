let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"~/workspace/badaniya/NVO-6520/GoDCApp/NVO\" }, { name = \"Test/src/test/runonce/unit/grpc_onboarding/grpc_onboarding_test.go\" }, { name = \"Test/src/test/runonce/functional/grpc_onboarding/grpc_onboarding_test.go\" }, { name = \"Common/src/infra/eventing/events/model/constants.go\" }, { name = \"RunOnce/Jenkinsfile\" }, { name = \"Test/src/test/runonce/testutils/utils.go\" }, { name = \"Network/Jenkinsfile\" }, { name = \"RunOnce/src/runonce/main.go\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6520/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +586 Test/src/test/runonce/unit/grpc_onboarding/grpc_onboarding_test.go
badd +45 Test/src/test/runonce/functional/grpc_onboarding/grpc_onboarding_test.go
badd +58 Common/src/infra/eventing/events/model/constants.go
badd +117 RunOnce/Jenkinsfile
badd +1 Test/src/test/runonce/testutils/utils.go
badd +124 Network/Jenkinsfile
badd +1 ~/workspace/badaniya/NVO-6520/GoDCApp/NVO/RunOnce/src/runonce/main.go
argglobal
%argdel
edit ~/workspace/badaniya/NVO-6520/GoDCApp/NVO/RunOnce/src/runonce/main.go
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
exe 'vert 1resize ' . ((&columns * 40 + 136) / 273)
exe 'vert 2resize ' . ((&columns * 232 + 136) / 273)
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt RunOnce/Jenkinsfile
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
balt Network/Jenkinsfile
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
let s:l = 40 - ((39 * winheight(0) + 36) / 73)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 40
normal! 0
wincmd w
exe 'vert 1resize ' . ((&columns * 40 + 136) / 273)
exe 'vert 2resize ' . ((&columns * 232 + 136) / 273)
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
