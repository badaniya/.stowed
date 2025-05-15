let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Db_ui_buffer_name_generator =  0 
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -run '\\''Test_DeviceOnboardingExosStackReconnect$'\\'' ./Test/src/test/network/functional/usecase'; go test -v -timeout 0 -count 1 -tags ci_jenkins -run 'Test_DeviceOnboardingExosStackReconnect$' ./Test/src/test/network/functional/usecase"
let VimuxResetSequence = "q C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"proj/efa/alarms/efa_repl_alarms_3.3.0_dev_env.md\" }, { name = \"proj/efa/alarms/efa_repl_alarms_3.2.0.md\" }, { name = \"proj/efa/alarms/fabric_alarm_example.md\" }, { name = \"proj/efa/alarms/alarms_mtg_minutes.md\" }, { name = \"proj/efa/alarms/alarms_requirements.md\" }, { name = \"proj/efa/alerts/alert_notes.txt\" }, { name = \"proj/efa/alerts/alert_notifications.md\" }, { name = \"proj/efa/alerts/alert_rest_endpoints.md\" }, { name = \"proj/efa/alerts/efa_repl_alerts_3.3.0.dev_env.md\" } }"
let VimuxRunnerIndex = "%93"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/vaults/work
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +3 Makefile
badd +18 ~/vaults/work/proj/nvo/stack_integration_tests/wired3-c9_exos_stack_conversion_standby_remove.md
badd +1 ~/vaults/work/proj/nvo/stack_integration_tests/wired3-c9_exos_stack_conversion_standby_add.md
badd +44 ~/vaults/work/proj/nvo/stack_integration_tests/wired3-c9_exos_stack_conversion_standby_initial.md
badd +79 ~/vaults/work/proj/nvo/stack_integration_tests/wired3-c9_exos_stack_conversion_backup_add.md
badd +50 ~/vaults/work/proj/nvo/stack_integration_tests/wired3-c9_exos_stack_conversion_backup_initial.md
badd +1 ~/vaults/work/proj/nvo/stack_integration_tests/wired3-c9_exos_stack_conversion_backup_remove.md
badd +58 ~/vaults/work/proj/nvo/stack_integration_tests/briana-c9_exos_stack_conversion_backup_add.md
badd +108 ~/vaults/work/proj/nvo/stack_integration_tests/briana-c9_exos_stack_conversion_backup_remove.md
badd +74 ~/vaults/work/proj/nvo/stack_integration_tests/nvo1r1_exos_stack_conversion_backup_add.md
badd +62 ~/vaults/work/proj/nvo/stack_integration_tests/nvo1r1_exos_stack_conversion_backup_initial.md
badd +110 ~/vaults/work/proj/nvo/stack_integration_tests/nvo1r1_exos_stack_conversion_backup_remove.md
argglobal
%argdel
edit ~/vaults/work/proj/nvo/stack_integration_tests/wired3-c9_exos_stack_conversion_standby_add.md
argglobal
balt ~/vaults/work/proj/nvo/stack_integration_tests/wired3-c9_exos_stack_conversion_backup_remove.md
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
let s:l = 1 - ((0 * winheight(0) + 29) / 58)
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
