let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let VimuxOpenExtraArgs = ""
let VimuxRunnerType = "pane"
let VimuxHeight = "20%"
let VimuxTmuxCommand = "tmux"
let VimuxResetSequence = "C-u"
let VimuxPromptString = "Command? "
let Bufferline__session_restore = "lua require('barbar.state').restore_buffers { { name = \"ConfigState/etc/yang/asset/extreme-asset-wireless-interface.yang\", pinned = true }, { name = \"ConfigState/etc/yang/inferred/extreme-inferred-wireless-interface.yang\", pinned = true }, { name = \"ConfigState/src/configstate/domain/models/asset/AssetInterface.go\" }, { name = \"ConfigState/src/configstate/domain/models/asset/AssetSsidConfig.go\" }, { name = \"ConfigState/src/configstate/domain/models/asset/AssetPortState.go\" }, { name = \"ConfigState/src/configstate/domain/models/asset/AssetWirelessInterface.go\" }, { name = \"ConfigState/src/configstate/domain/models/asset/AssetWirelessInterfaceState.go\" }, { name = \"ConfigState/src/configstate/domain/models/inferred/InferredWirelessInterface.go\" }, { name = \"ConfigState/src/configstate/domain/models/inferred/InferredUtilizationInfo.go\" }, { name = \"ConfigState/src/configstate/domain/models/asset/enum.go\" }, { name = \"ConfigState/src/configstate/domain/models/inferred/InferredWirelessInterfaceErrorStats.go\" }, { name = \"ConfigState/src/configstate/domain/models/inferred/InferredWirelessInterfaceInOutStats.go\" }, { name = \"ConfigState/src/configstate/domain/models/inferred/InferredWirelessInterfaceUtilizationInfo.go\" }, { name = \"ConfigState/etc/database/migrations/atlas.sum\" }, { name = \"ConfigState/src/configstate/usecase/database_functions.go\" }, { name = \"ConfigState/etc/database/views/schema/create_views.sql\" }, { name = \"ConfigState/src/configstate/domain/models/asset/AssetLldpNeighborState.go\" }, { name = \"ConfigState/etc/database/views/model_generator.go\" }, { name = \"ConfigState/etc/database/Dockerfile\" }, { name = \"ConfigState/etc/database/master-change-cs-log.yaml\" }, { name = \"ConfigState/etc/database/run_cs_liquibase_update.sh\" }, { name = \"ConfigState/etc/database/atlas.hcl\" }, { name = \"ConfigState/etc/database/main/loader.go\" }, { name = \"ConfigState/src/configstate/domain/schema.go\" }, { name = \"ConfigState/README.md\" }, { name = \"Common/Readme.md\" }, { name = \"ConfigState/etc/scripts/README.md\" }, { name = \"ConfigState/pyang_readme.md\" }, { name = \"ConfigState/etc/database/liquibase.properties\" } }"
let VimuxOrientation = "v"
let VimuxRunnerName = ""
silent only
silent tabonly
cd ~/workspace/badaniya/NVO-6555/PlatformServices
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
let s:shortmess_save = &shortmess
if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif
badd +303 ConfigState/etc/database/views/schema/create_views.sql
badd +5 ConfigState/etc/database/migrations/atlas.sum
badd +133 ConfigState/etc/yang/asset/extreme-asset-wireless-interface.yang
badd +71 ConfigState/etc/yang/inferred/extreme-inferred-wireless-interface.yang
badd +175 ConfigState/src/configstate/domain/models/asset/AssetLldpNeighborState.go
badd +35 ConfigState/src/configstate/domain/models/asset/AssetSsidConfig.go
badd +86 ConfigState/src/configstate/domain/models/asset/AssetPortState.go
badd +53 ConfigState/etc/database/views/model_generator.go
badd +32 ConfigState/src/configstate/domain/models/asset/AssetWirelessInterface.go
badd +58 ConfigState/src/configstate/domain/models/asset/AssetWirelessInterfaceState.go
badd +1731 ConfigState/src/configstate/domain/models/asset/enum.go
badd +129 ConfigState/src/configstate/domain/models/asset/AssetInterface.go
badd +45 ConfigState/src/configstate/domain/models/inferred/InferredWirelessInterface.go
badd +32 ConfigState/src/configstate/domain/models/inferred/InferredUtilizationInfo.go
badd +62 ConfigState/src/configstate/domain/models/inferred/InferredWirelessInterfaceErrorStats.go
badd +43 ConfigState/src/configstate/domain/models/inferred/InferredWirelessInterfaceInOutStats.go
badd +32 ConfigState/src/configstate/domain/models/inferred/InferredWirelessInterfaceUtilizationInfo.go
badd +2462 ConfigState/src/configstate/usecase/database_functions.go
badd +1 ConfigState/etc/database/Dockerfile
badd +5 ConfigState/etc/database/master-change-cs-log.yaml
badd +1 ConfigState/etc/database/run_cs_liquibase_update.sh
badd +1 ConfigState/etc/database/atlas.hcl
badd +13 ConfigState/etc/database/main/loader.go
badd +177 ConfigState/src/configstate/domain/schema.go
badd +167 ConfigState/README.md
badd +1 Common/Readme.md
badd +170 ConfigState/etc/scripts/README.md
badd +1 ConfigState/pyang_readme.md
badd +1 ConfigState/etc/database/liquibase.properties
argglobal
%argdel
edit ConfigState/etc/database/migrations/atlas.sum
wincmd t
let s:save_winminheight = &winminheight
let s:save_winminwidth = &winminwidth
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
argglobal
balt ConfigState/etc/database/views/schema/create_views.sql
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
let s:l = 5 - ((4 * winheight(0) + 21) / 42)
if s:l < 1 | let s:l = 1 | endif
keepjumps exe s:l
normal! zt
keepjumps 5
normal! 037|
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
