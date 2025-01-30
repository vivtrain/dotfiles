require "nvchad.mappings"

local map = vim.keymap.set
--local unmap = vim.keymap.del

map("i", "jk", "<esc>", { desc = "Go back to normal mode" })
map("i", "kj", "<esc>", { desc = "Go back to normal mode" })
map("n", "<tab>", "<c-w>", { desc = "Window navigation prefix" })
map("n", "+", "<c-w>+", { desc = "Adjust split height up" })
map("n", "_", "<c-w>-", { desc = "Adjust split height down" })
map("n", "]]", "<cmd> vert res -1 <cr>", { desc = "Adjust split width right" })
map("n", "[[", "<cmd> vert res +1 <cr>", { desc = "Adjust split width left" })
map("n", "0", "^", { desc = "Jump to first non-whitespace character" })
map("n", "^", "<home>", { desc = "Jump to beginning of line" })
map("n", "Y", "y$", { desc = "Copy to end of line" })
map("n", "Q", "@@", { desc = "Repeat most recent macro" })
map("n", "<c-space>", "<cmd> lua vim.diagnostic.open_float() <cr>", { desc = "Open float window" })
map("n", "<c-n>", "<cmd> NvimTreeFocus <cr>", { desc = "NvimTree open or jump to explorer" })
map("n", "U", "<c-r>", { desc = "Redo" })
map("i", "<c-h>", "<c-w>", { desc = "Delete one word backwards" })

local cmp = require("cmp")
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ['<cr>'] = cmp.mapping.confirm({ select = false }),
  })
})

--map("n", "<tab>q", "<c-w>w")
-- Buffer navigation
--map("i", "<c-h>", "<left>")
--map("i", "<c-j>", "<down>")
--map("i", "<c-k>", "<up>")
--map("i", "<c-l>", "<right>")
--Be able to move within insert mode using hjkl
--map("n", "<leader>M", ":set mouse=a<cr>")
--map("n", "<leader>m", ":set mouse=\"\"<cr>")
-- Misc
--map("n", "<leader>q", ":mks!<cr>:wqa<cr>")
--Quit after saving the session
--map("n", "<leader>s", ":source ~/.vimrc<cr>:noh<cr>")
--Source .vimrc to easily implement changes
--map("n", "S", ":%s//gc<left><left><left>")
--Search and Replace, whole file, ask first
--map("n", "<leader>N", ":set relativenumber!<cr>")
--Toggles relative line numbers
--map("n", "<leader>T", ":set expandtab!<cr>:set expandtab?<cr>")
--Toggle tab expansion
--map("n", "<leader>t", ":%s/\t/    /g<cr>")
--Swap tab characters with four spaces
--map("v", "<leader>c", ":w !clip.exe<cr>q")
--Send to system clipboard on WSL
--map("n", "<leader>p", ":set paste!<cr>")
--Toggle paste mode
--map("n", "<leader>w", "m':%s/  *$//ge<cr>'':noh<cr>")
--Eliminate trailing whitespace
--map("n", "<leader>n", ":noh<cr>")
--Stop highlighting (e.g. after a search)
--map("n", "<leader><cr>", "o<esc>k")
--Add an empty line without leaving normal mode
--map("n", "<leader>-", "i-<esc>vy79p<home>R")
--Subheader for .txt notes
--map("n", "<leader>=", "i=<esc>vy79pyypO<tab>")
--Header for .txt notes
--map("i", "{<cr>", "{<cr>}<esc>O")
--Uses auto indenting to create a new code block

