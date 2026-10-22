" === Ensure Node uses system CA certificates for Copilot ===
let $NODE_EXTRA_CA_CERTS = "/etc/ssl/certs/ca-certificates.crt"

" Optional: disable strict SSL verification (less secure)
" let $NODE_TLS_REJECT_UNAUTHORIZED = "0"

" ============================
" ===== Plugin Manager ======
" ============================
call plug#begin('~/.config/nvim/plugged')

" File explorer
Plug 'nvim-tree/nvim-tree.lua'

" Status bar
Plug 'nvim-lualine/lualine.nvim'

" GitHub Copilot
Plug 'github/copilot.vim'

" Markdown preview
Plug 'OXY2DEV/markview.nvim'

" Syntax highlighting
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'catppuccin/nvim', {'as': 'catppuccin'}
Plug 'NvChad/nvim-colorizer.lua'

" Git signs in the gutter
Plug 'lewis6991/gitsigns.nvim'

" Buffer line
Plug 'akinsho/bufferline.nvim'

call plug#end()

" ============================
" ===== Basic Settings =======
" ============================
syntax on
set number
set mouse=a
set tabstop=4
set shiftwidth=4
set expandtab

" Leader key (space)
let mapleader = " "

" ============================
" ===== NvimTree Setup =======
" ============================
lua << EOF
require('nvim-tree').setup {
  view = {
    width = 30,
    side = 'left',
  },
  git = {
    enable = true,
    ignore = false,
    timeout = 400,
  },
  renderer = {
    icons = {
      show = {
        git = true,
        folder = true,
        file = true,
      },
    },
  },
}
EOF

" Keymaps for NvimTree
nnoremap <C-n> :NvimTreeToggle<CR>
nnoremap <leader>e :NvimTreeFocus<CR>
nnoremap <leader>f :NvimTreeFindFile<CR>

" ====================================
" ===== Catppuccin Theme Setup ======
" ====================================
lua << EOF
require('catppuccin').setup({
  flavour = 'mocha',
  transparent_background = true,
  term_colors = true,
  styles = {
    comments = {'italic'},
    functions = {'bold'},
    keywords = {'bold'},
    strings = {},
    variables = {},
  },
  integrations = {
    lualine = true,
    gitsigns = true,
    nvimtree = true,
    treesitter = true,
  },
})

vim.cmd [[colorscheme catppuccin]]
EOF

" ============================
" ===== Lualine Setup ========
" ============================
lua << EOF
require('lualine').setup {}
EOF

" ============================
" ===== Colorizer Setup ======
" ============================
lua << EOF
local ok, colorizer = pcall(require, 'colorizer')
if ok then
  colorizer.setup({
    filetypes = { '*' },
    user_default_options = {
      RGB = true,
      RRGGBB = true,
      RRGGBBAA = true,
      AARRGGBB = true,
      rgb_fn = true,
      hsl_fn = true,
      css = true,
      css_fn = true,
      mode = 'virtualtext',
      virtualtext = '■',
    },
  })
end
EOF

" ============================
" ===== Gitsigns Setup =======
" ============================
lua << EOF
require('gitsigns').setup {
  signs = {
    add          = {hl = 'GitGutterAdd',    text = '│', numhl = 'GitSignsAddNr',    linehl = 'GitSignsAddLn'},
    change       = {hl = 'GitGutterChange', text = '│', numhl = 'GitSignsChangeNr', linehl = 'GitSignsChangeLn'},
    delete       = {hl = 'GitGutterDelete', text = '_', numhl = 'GitSignsDeleteNr', linehl = 'GitSignsDeleteLn'},
    topdelete    = {hl = 'GitGutterDelete', text = '‾', numhl = 'GitSignsDeleteNr', linehl = 'GitSignsDeleteLn'},
    changedelete = {hl = 'GitGutterChange', text = '~', numhl = 'GitSignsChangeNr', linehl = 'GitSignsChangeLn'},
  },
  numhl = true,
  linehl = false,
  watch_gitdir = {interval = 1000},
  current_line_blame = false,
}
EOF

" Buffer navigation keymaps
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>
nnoremap <leader>c :bdelete<CR>

" Save with Ctrl+S
nnoremap <C-s> :update<CR>3
inoremap <C-s> <Esc>:update<CR>gi
vnoremap <C-s> <Esc>:update<CR>gv
