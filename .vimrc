set nocompatible              " be iMproved, required

" Initial Settings""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
syntax on
filetype plugin indent on         " use filetype settings
set encoding=utf-8
set background=dark               " dark background
set timeoutlen=1000 ttimeoutlen=0 " set a 1 sec timout for map leader
set backspace=indent,eol,start    " make backspace work
set shell=/bin/bash
set noerrorbells

if has("autocmd")
    au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
        \| exe "normal! g'\"" | endif
endif

" " set 'updatetime' to 15 seconds when in insert mode
" au InsertEnter * let updaterestore=&updatetime | set updatetime=15000
" au InsertLeave * let &updatetime=updaterestore
" " automatically leave insert mode after 'updatetime' milliseconds of inaction
" au CursorHoldI * stopinsert

" Set escape sequences so Vim knows how to change cursor on Windows Console Host
let &t_SI = "\<Esc>[6 q"
let &t_SR = "\<Esc>[3 q"
let &t_EI = "\<Esc>[2 q"

" Fix arrow keys in Windows Console Host
if !has('nvim')
  set esckeys
  set <up>=OA
  set <down>=OB
  set <right>=OC
  set <left>=OD
endif

" Vim Native Package Manager""""""""""""""""""""""""""""""""""""""""""""""""""""
"if !has('nvim')
"  packadd YouCompleteMe
"  let g:ycm_global_ycm_extra_conf = '/home/k99vivek/.vim/pack/YouCompleteMe/opt/YouCompleteMe/third_party/ycmd/.ycm_extra_conf.py'
"  let g:ycm_confirm_extra_conf = 0
"  let g:python_highlight_all = 1
"endif

" Formatting""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Tabbing
set expandtab
set shiftround
set nosmartindent
set autoindent

set tabstop=2           " Tab length of 2 characters
set shiftwidth=2        " Normal mode tabbing to match ^
set softtabstop=2
set smarttab

set list
set listchars=tab:>-    " Show tabs as >-

" C-Style Language Specific Formatting
autocmd Filetype c,cpp,objc,cc set cindent tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType cpp source ~/.vim/pack/cppman/start/dir/opt/cpp.vim

" Python Specific Formatting
autocmd Filetype python set tabstop=2 shiftwidth=2 softtabstop=2

" Matlab Formatting
autocmd Filetype m set tabstop=2 shiftwidth=2 softtabstop=2

" Maps""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let mapleader=" "
" Window navigation
nnoremap <tab>              <c-w>
nnoremap <tab>q             <c-w>w
nnoremap +                  <c-w>+
nnoremap -                  <c-w>-
" Buffer navigation
inoremap <c-h>              <left>
inoremap <c-j>              <down>
inoremap <c-k>              <up>
inoremap <c-l>              <right>
                            " Be able to move within insert mode using hjkl
nnoremap 0                  ^
nnoremap ^                  <home>
                            " 0 easier to hit than ^ so swap their functions
nnoremap Y                  y$
                            " Make this consistent with D, since yy exists
nnoremap Q                  @@
                            " Repeat last macro, since I don't use ex mode
nnoremap <leader>M          :set mouse=a<cr>
nnoremap <leader>m          :set mouse=""<cr>
" Misc
nnoremap <leader>q          :mks!<cr>:wqa<cr>
                            " Quit after saving the session
nnoremap <leader>s          :source ~/.vimrc<cr>:noh<cr>
                            " Source .vimrc to easily implement changes
nnoremap S                  :%s//gc<left><left><left>
                            " Search and Replace, whole file, ask first
nnoremap <leader>N          :set relativenumber!<cr>
                            " Toggles relative line numbers
nnoremap <leader>T          :set expandtab!<cr>:set expandtab?<cr>
                            " Toggle tab expansion
nnoremap <leader>t          :%s/\t/    /g<cr>
                            " Swap tab characters with four spaces
vnoremap <leader>c          :w !clip.exe<cr>q
                            " Send to system clipboard on WSL
nnoremap <leader>p          :set paste!<cr>
                            " Toggle paste mode
nnoremap <leader>w          m':%s/  *$//ge<cr>'':noh<cr>
                            " Eliminate trailing whitespace
nnoremap <leader>n          :noh<cr>
                            " Stop highlighting (e.g. after a search)
nnoremap <leader>f          :YcmCompleter FixIt<cr>
                            " Try to YCM fix on the current line
nnoremap <leader><cr>       o<esc>k
                            " Add an empty line without leaving normal mode
nnoremap <leader>-          i-<esc>vy79p<home>R
                            " Subheader for .txt notes
nnoremap <leader>=          i=<esc>vy79pyypO<tab>
                            " Header for .txt notes
inoremap {<cr>              {<cr>}<esc>O
                            " Uses auto indenting to create a new code block

" Display"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
set showcmd             " Show (partial) command in status line.
set showmatch           " Show matching brackets.
set smartcase           " Do smart case matching
set incsearch           " Incremental search
set hlsearch            " Highlight search
set hidden              " Hide buffers when they are abandoned
set laststatus=2        " Always show the status bar with mode, file name, etc.
set wrap                " Show long lines as multiple lines
set scrolloff=5         " Whenever possible, show N lines around cursor
set t_Co=256            " Pretty Colors

"set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<

set splitbelow          " sp creates below
set splitright          " vsp creates to the right

" Cursor color
hi Cursor ctermbg=white ctermfg=black

" Highlight current vert position
set cursorline
hi clear CursorLine
hi CursorLine ctermbg=235

" 80 Character line
set colorcolumn=81      " Colors column 81
"set tw=80               " Automatically newlines at a new word that passes 80
hi ColorColumn ctermbg=233
hi LineNr ctermfg=15 ctermbg=233

" YCM Highlights
" Column for breakpoints and YCM >> signs
hi SignColumn ctermbg=234
" YcmErrorSign
hi Error ctermbg=1
" YcmErrorSection
hi SpellBad ctermbg=52
" YcmWarningSign
hi Todo ctermbg=228
" YcmWarningSection
hi SpellCap ctermbg=58

" Vim CPP Modern highlights
hi cppSTLnamespace ctermfg=244
hi cppAccess ctermfg=222

" Menu (used by YCM for suggestions)
hi Pmenu ctermbg=237 ctermfg=255

" General syntax colors
hi Comment ctermfg=39
hi Include ctermfg=176
hi Constant ctermfg=201
hi Statement ctermfg=228
hi Special ctermfg=219
hi Function ctermfg=123

" Line number options
set number              " Show line numbers
set norelativenumber    " Unset line numbers relative to current
set numberwidth=3       " Make room for a three digit line number

" Highlight extra whitespace
highlight ExtraWhitespace ctermbg=white guibg=white
autocmd ColorScheme * highlight ExtraWhitespace ctermbg=white guibg=white
match ExtraWhitespace /\s\+\%#\@<!$/
