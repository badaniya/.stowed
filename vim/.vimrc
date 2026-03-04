call plug#begin('~/.vim/plugged')
    Plug 'fatih/vim-go', { 'do': ':GoInstallBinaries' }
    Plug 'scrooloose/nerdtree'
    Plug 'Xuyuanp/nerdtree-git-plugin'
    Plug 'itchyny/lightline.vim'
    Plug 'tpope/vim-fugitive'
    Plug 'airblade/vim-gitgutter'
    Plug 'wincent/ferret'
call plug#end()

let g:tagbar_type_go = {
	\ 'ctagstype' : 'go',
	\ 'kinds'     : [
		\ 'p:package',
		\ 'i:imports:1',
		\ 'c:constants',
		\ 'v:variables',
		\ 't:types',
		\ 'n:interfaces',
		\ 'w:fields',
		\ 'e:embedded',
		\ 'm:methods',
		\ 'r:constructor',
		\ 'f:functions'
	\ ],
	\ 'sro' : '.',
	\ 'kind2scope' : {
		\ 't' : 'ctype',
		\ 'n' : 'ntype'
	\ },
	\ 'scope2kind' : {
		\ 'ctype' : 't',
		\ 'ntype' : 'n'
	\ },
	\ 'ctagsbin'  : 'gotags',
	\ 'ctagsargs' : '-sort -silent'
\ }

let g:go_addtags_transform = "camelcase"
let g:go_highlight_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_function_calls = 1
let g:go_highlight_operators = 1
let g:go_highlight_extra_types = 1
let g:go_highlight_build_constraints = 1
let g:go_def_mode='gopls'
let g:go_info_mode='gopls'

let CURRENT_FILE = expand("%:t")

if CURRENT_FILE =~ "Makefile" || CURRENT_FILE =~ "makefile" || CURRENT_FILE =~ ".*\.mk" || CURRENT_FILE =~ ".*\.make"
    set noexpandtab
else
    set expandtab
endif

set tabstop=4
set shiftwidth=4

"Enable CTRL-] to search cscope and ctags                                                                                                                                          
set cscopetag   

"CTRL-] precedence                                                                                                                                                                 
"    csto=0 : prefer cscope                                                                                                                                                        
"    csto=1 : prefer ctags                                                                                                                                                         
set csto=1 

let CTAG_FILE=$CTAG_CSCOPE_PATH . '/.' . $CLEARCASE_VIEW . '_tags'
let CSCOPE_FILE=$CTAG_CSCOPE_PATH . '/.' . $CLEARCASE_VIEW . '_cscope.out'

if !filereadable(CTAG_FILE)
    let CTAG_FILE=$CTAG_CSCOPE_DEFAULT_VIEW_PATH . '/.' . $CLEARCASE_VIEW . '_tags'
endif 

if !filereadable(CSCOPE_FILE)
    let CSCOPE_FILE=$CTAG_CSCOPE_DEFAULT_VIEW_PATH . '/.' . $CLEARCASE_VIEW . '_cscope.out'
endif

if filereadable(CTAG_FILE)
    execute 'set tags=' . CTAG_FILE
endif

if has('cscope')

    "if has('quickfix')
    "  set cscopequickfix=s-,c-,d-,i-,t-,e-
    "endif

    cnoreabbrev csa cs add
    cnoreabbrev csf cs find
    cnoreabbrev csk cs kill
    cnoreabbrev csr cs reset
    cnoreabbrev css cs show
    cnoreabbrev csh cs help

    set nocsverb

    if filereadable(CSCOPE_FILE)
        execute 'cs add ' . CSCOPE_FILE
    endif

    set csverb

endif

"NERDTree mapping
nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>

" Store the bookmarks file
let NERDTreeBookmarksFile=expand("$HOME/.vim-NERDTreeBookmarks")
" Show the bookmarks table on startup
let NERDTreeShowBookmarks=1

nnoremap <F2> :set invpaste paste?<CR>
set pastetoggle=<F2>
set showmode

syntax on
filetype on
"highlight Normal ctermbg=NONE
"colorscheme morning
colorscheme zenburn

set redrawtime=10000
set maxmempattern=100000
