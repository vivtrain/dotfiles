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
map({"t","n"}, "<c-p>", "<cmd> wincmd p <cr>", { desc = "Terminal Return to editor buffer" })

map("n", "0", "^", { desc = "Jump to first non-whitespace character" })
map("n", "^", "<home>", { desc = "Jump to beginning of line" })
map("n", "Y", "y$", { desc = "Yank to end of line" })
map("n", "U", "<c-r>", { desc = "Redo" })
map("n", "Q", "@@", { desc = "Repeat most recent macro" })

map("n", "<c-n>", "<cmd> NvimTreeFocus <cr>", { desc = "NvimTree open or jump to explorer" })
map("n", "<c-f>", "<cmd> NvimTreeFindFile <cr>", { desc = "NvimTree show in explorer "})

map("n", "<c-space>", "<cmd> lua vim.diagnostic.open_float() <cr>", { desc = "Open float window" })
map("n", "<F2>", "<cmd> lua require 'nvchad.lsp.renamer'() <cr>", { desc = "LSP Rename variable "})
map("n", "<leader>l", "<cmd> LspStop <cr><cmd> LspStart <cr>", { desc = "LSP Restart"})

map("n", "<leader>db", "<cmd> DapToggleBreakpoint <cr>", { desc = "DAP Toggle Breakpoint"})
map("n", "<leader>dn", "<cmd> NvimTreeClose <cr><cmd> DapNew <cr>", { desc = "DAP New session"})
map("n", "<leader>dd", "<cmd> DapDisconnect <cr>", { desc = "DAP DapDisconnect"})
map("n", "<F7>", "<cmd> DapStepOut <cr>", { desc = "DAP DapDisconnect"})
map("n", "<F8>", "<cmd> DapStepInto <cr>", { desc = "DAP DapDisconnect"})
map("n", "<F9>", "<cmd> DapStepOver <cr>", { desc = "DAP DapDisconnect"})
map("n", "<F10>", "<cmd> DapContinue <cr>", { desc = "DAP Continue"})

map("n", "ZZ", "<cmd> :wqa <cr>", { desc = "Exit Quit Neovim after saving" })
map("n", "ZX", "<cmd> :qa! <cr>", { desc = "Exit Quit Neovim without saving" })

