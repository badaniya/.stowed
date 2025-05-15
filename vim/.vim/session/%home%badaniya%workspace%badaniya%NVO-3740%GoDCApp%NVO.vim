let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-3740/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +351 Network/src/network/usecase/correlator/physical_link_correlator.go
badd +85 Network/src/network/usecase/discovery.go
badd +163 Network/src/network/usecase/correlator/device_correlator.go
badd +52 Network/src/network/usecase/collector/system_collector.go
badd +42 Network/src/network/usecase/onboarding.go
badd +1 Network/src/network/usecase/correlator/lag_correlator.go
badd +1 Edge/Makefile
badd +36 RunOnce/src/runonce/usecase/grpc_onboarding.go
badd +0 Network/RunOnce/src/runonce/usecase/grpc_onboarding.go
argglobal
%argdel
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
