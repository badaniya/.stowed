let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"ConfigState/etc/yang/common/extreme-common-types.yang\" }, { name = \"ConfigState/etc/yang/asset/extreme-asset-slot.yang\" }, { name = \"ConfigState/etc/yang/asset/extreme-asset-device.yang\" }, { name = \"ConfigState/etc/yang/inferred/extreme-inferred-slot.yang\" }, { name = \"ConfigState/etc/yang/asset/extreme-asset-types.yang\" }, { name = \"ConfigState/etc/yang/inferred/extreme-inferred-types.yang\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-7530/PlatformCommonModels
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +190 ~/workspace/badaniya/NVO-7530/PlatformCommonModels/ConfigState/etc/yang/common/extreme-common-types.yang
badd +48 ~/workspace/badaniya/NVO-7530/PlatformCommonModels/ConfigState/etc/yang/inferred/extreme-inferred-slot.yang
badd +26 ~/workspace/badaniya/NVO-7530/PlatformCommonModels/ConfigState/etc/yang/asset/extreme-asset-slot.yang
badd +106 ~/workspace/badaniya/NVO-7530/PlatformCommonModels/ConfigState/etc/yang/asset/extreme-asset-device.yang
badd +731 ~/workspace/badaniya/NVO-7530/PlatformCommonModels/ConfigState/etc/yang/asset/extreme-asset-types.yang
badd +1345 ~/workspace/badaniya/NVO-7530/PlatformCommonModels/ConfigState/etc/yang/inferred/extreme-inferred-types.yang
argglobal
%argdel
edit ~/workspace/badaniya/NVO-7530/PlatformCommonModels/ConfigState/etc/yang/inferred/extreme-inferred-types.yang
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
wincmd =
argglobal
enew
file neo-tree\ filesystem\ \[1]
balt ~/workspace/badaniya/NVO-7530/PlatformCommonModels/ConfigState/etc/yang/common/extreme-common-types.yang
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
balt ~/workspace/badaniya/NVO-7530/PlatformCommonModels/ConfigState/etc/yang/asset/extreme-asset-types.yang
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
let s:l = 1345 - ((18 * winheight(0) + 16) / 33)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 1345
normal! 0
wincmd w
2wincmd w
wincmd =
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
