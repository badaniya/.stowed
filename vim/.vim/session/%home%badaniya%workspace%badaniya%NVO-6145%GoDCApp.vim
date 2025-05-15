let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6145/GoDCApp
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +53 NVO/System/src/system/infra/rest/openapi/handler/physical_link.go
badd +662 NVO/System/src/system/infra/rest/openapi/handler/topology.go
badd +53 NVO/System/src/system/usecase/lag.go
badd +354 NVO/Common/src/infra/marshal/topology_edge.go
badd +76 NVO/System/src/system/infra/rest/routers.go
badd +72 NVO/Test/src/test/system/unit/usecase/get_device_physical_link_test.go
badd +501 NVO/Test/src/test/system/unit/grpc_portstats/grpc_portstats_test.go
badd +118 NVO/Test/src/test/system/testutils/inferred_domain_utils.go
badd +20 NVO/Common/src/domain/models/inferred/interface.go
badd +17 NVO/Common/src/domain/models/inferred/managed_device.go
badd +20 NVO/Common/src/domain/models/inferred/physical_link.go
badd +26 NVO/Common/src/domain/models/network/interface.go
badd +186 NVO/Common/src/gateway/database/generic_operations.go
badd +1 NVO/Common/src/infra/utils/error_constants.go
badd +104 NVO/Common/src/infra/system/auth.go
badd +62 NVO/Common/src/gateway/middleware/header.go
badd +36 NVO/Common/src/infra/utils/context.go
argglobal
%argdel
edit NVO/Test/src/test/system/testutils/inferred_domain_utils.go
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
tcd ~/workspace/badaniya/NVO-6145/GoDCApp/NVO
argglobal
balt ~/workspace/badaniya/NVO-6145/GoDCApp/NVO/Common/src/domain/models/inferred/interface.go
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
let s:l = 1 - ((0 * winheight(0) + 31) / 63)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1
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
