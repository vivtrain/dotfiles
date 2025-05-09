require "nvchad.mappings"

local map = vim.keymap.set
--local unmap = vim.keymap.del

map("i", "jk", "<esc>", { desc = "Exit insert mode" })
map("i", "kj", "<esc>", { desc = "Exit insert mode" })
map("n", "<tab>", "<c-w>", { desc = "Window navigation prefix" })
map("n", "+", "<c-w>+", { desc = "Window Adjust split height up" })
map("n", "_", "<c-w>-", { desc = "Window Adjust split height down" })
map("n", "]]", "<cmd> vert res -1 <cr>", { desc = "Window Adjust split width right" })
map("n", "[[", "<cmd> vert res +1 <cr>", { desc = "Window Adjust split width left" })
map("n", "0", "^", { desc = "Jump to first non-whitespace character" })
map("n", "^", "<home>", { desc = "Jump to beginning of line" })
map("n", "Y", "y$", { desc = "Yank to end of line" })
map("n", "Q", "@@", { desc = "Repeat most recent macro" })
map("n", "<c-space>", "<cmd> lua vim.diagnostic.open_float() <cr>", { desc = "Open float window" })
map("n", "<c-n>", "<cmd> NvimTreeFocus <cr>", { desc = "NvimTree open or jump to explorer" })
map("n", "U", "<c-r>", { desc = "Redo" })
map("n", "<leader>ra", "<cmd> lua require 'nvchad.lsp.renamer'() <cr>", { desc = "LSP Rename variable "})
map("n", "<F2>", "<cmd> lua require 'nvchad.lsp.renamer'() <cr>", { desc = "LSP Rename variable "})

local cmp = require("cmp")
cmp.setup({
  mapping = cmp.mapping.preset.insert({
    ['<cr>'] = cmp.mapping.confirm({ select = false }),
  })
})


-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
