let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-3692/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +1 Scheduler/src/scheduler/main.go
badd +29 Scheduler/src/scheduler/test/functional/scheduler_test.go
badd +69 Common/src/infra/grpc/generated/schedulerclient/scheduler_grpc.pb.go
badd +420 ~/.go/pkg/mod/google.golang.org/grpc@v1.65.0/clientconn.go
badd +1 /tmp/nvim.badaniya/cr8O3o/nvo_db-query-2024-08-22-10-52-10
badd +24 ~/workspace/badaniya/NVO-3692/GoDCApp/NVO/Common/src/infra/grpc/grpcinfra.go
argglobal
%argdel
edit Scheduler/src/scheduler/test/functional/scheduler_test.go
argglobal
balt ~/workspace/badaniya/NVO-3692/GoDCApp/NVO/Common/src/infra/grpc/grpcinfra.go
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
let s:l = 56 - ((41 * winheight(0) + 32) / 64)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 56
normal! 068|
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
let g:this_session = v:this_session
let g:this_obsession = v:this_session
doautoall SessionLoadPost
unlet SessionLoad
" vim: set ft=vim :
