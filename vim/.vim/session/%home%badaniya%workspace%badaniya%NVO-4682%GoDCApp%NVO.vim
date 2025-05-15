let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let Db_ui_buffer_name_generator =  0 
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxLastCommand = "clear; echo -e 'go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run '\\''TestNvoWorkerAllTaskSuccessEndOfStageMergeContextMapEntryORedPerTaskInSingleStage_PRSanity$'\\'' ./Test/src/test/Common/unit/nvoworker'; go test -v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all -run 'TestNvoWorkerAllTaskSuccessEndOfStageMergeContextMapEntryORedPerTaskInSingleStage_PRSanity$' ./Test/src/test/Common/unit/nvoworker"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"Common/src/infra/nvoworker/nvoworker.go\", pinned = true }, { name = \"Test/src/test/edge/test/functional/collectors/exos_vlan_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/fabric_attach_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/fdb_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/interface_vlan_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/ip_arp_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/l2vsncollector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/l3vsncollector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/neigh_disc_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/vlan_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/vlan_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/voss_collectors_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/voss_l2vsn_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/voss_l3_vsn_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/voss_vlan_collector_util.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/vrf_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/vrf_utils.go\" }, { name = \"Test/src/test/edge/test/functional/collectors/vrrp_collector_utils.go\" }, { name = \"Test/src/test/edge/test/functional/correlators/fabric_attach_correlator_test.go\" }, { name = \"Test/src/test/edge/test/functional/correlators/l2service_correlators_test.go\" }, { name = \"Test/src/test/edge/test/functional/correlators/l3service_correlators_test.go\" }, { name = \"Test/src/test/edge/test/functional/correlators/vlan_service_correlators_test.go\" }, { name = \"Test/src/test/edge/test/functional/correlators/vrf_correlators_test.go\" }, { name = \"Test/src/test/edge/test/functional/correlators/vrf_service_correlators_test.go\" }, { name = \"Test/src/test/edge/test/testutils/nvoworker_utils.go\" }, { name = \"Test/src/test/edge/test/testutils/utils.go\" }, { name = \"Test/src/test/edge/test/unit/usecase/correlator/correlator_partial_inference_test.go\" }, { name = \"Test/src/test/network/functional/usecase/collector/capabilities_collector_test.go\" } }"
let VimuxRunnerIndex = "%124"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-4682/GoDCApp/NVO
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +1 Common/src/infra/nvoworker/nvoworker.go
badd +359 Test/src/test/edge/test/testutils/utils.go
badd +1 Test/src/test/edge/test/testutils/nvoworker_utils.go
badd +244 Test/src/test/edge/test/functional/collectors/vrf_utils.go
badd +1294 Test/src/test/edge/test/functional/collectors/l2vsncollector_utils.go
badd +926 Test/src/test/edge/test/functional/collectors/vlan_collector_utils.go
badd +964 Test/src/test/edge/test/functional/collectors/voss_vlan_collector_util.go
badd +486 Test/src/test/edge/test/functional/collectors/neigh_disc_collector_utils.go
badd +117 Test/src/test/edge/test/functional/collectors/fdb_collector_utils.go
badd +170 Test/src/test/edge/test/functional/collectors/ip_arp_collector_utils.go
badd +556 Test/src/test/edge/test/functional/collectors/l3vsncollector_utils.go
badd +142 Test/src/test/edge/test/functional/collectors/exos_vlan_collector_utils.go
badd +106 Test/src/test/edge/test/functional/collectors/vrrp_collector_utils.go
badd +1126 Test/src/test/edge/test/functional/collectors/vrf_collector_utils.go
badd +598 Test/src/test/edge/test/functional/collectors/voss_l3_vsn_collector_utils.go
badd +218 Test/src/test/edge/test/functional/collectors/voss_l2vsn_collector_utils.go
badd +755 Test/src/test/edge/test/functional/collectors/vlan_utils.go
badd +826 Test/src/test/edge/test/functional/collectors/interface_vlan_collector_utils.go
badd +190 Test/src/test/edge/test/functional/collectors/fabric_attach_utils.go
badd +100 Test/src/test/edge/test/functional/collectors/voss_collectors_utils.go
badd +547 Test/src/test/edge/test/functional/correlators/fabric_attach_correlator_test.go
badd +953 Test/src/test/edge/test/functional/correlators/l2service_correlators_test.go
badd +121 Test/src/test/edge/test/functional/correlators/l3service_correlators_test.go
badd +272 Test/src/test/edge/test/functional/correlators/vlan_service_correlators_test.go
badd +305 Test/src/test/edge/test/functional/correlators/vrf_correlators_test.go
badd +686 Test/src/test/edge/test/functional/correlators/vrf_service_correlators_test.go
badd +35 Test/src/test/edge/test/unit/usecase/correlator/correlator_partial_inference_test.go
badd +31 Test/src/test/network/functional/usecase/collector/capabilities_collector_test.go
argglobal
%argdel
edit Test/src/test/edge/test/functional/collectors/fdb_collector_utils.go
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
balt Test/src/test/edge/test/functional/collectors/vlan_collector_utils.go
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
balt Common/src/infra/nvoworker/nvoworker.go
setlocal fdm=diff
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=0
setlocal fdn=20
setlocal fen
let s:l = 117 - ((52 * winheight(0) + 31) / 63)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 117
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
