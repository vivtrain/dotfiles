require "nvchad.mappings"

local map = vim.keymap.set
local unmap = vim.keymap.del
local function desc(desc)
  return { desc = desc }
end

unmap("n", "<leader>ch")
map("n", "<leader>ch", "<cmd> NvimTreeClose <cr><cmd> NvCheatsheet <cr>")

map("i", "jk", "<esc>", desc "Exit insert mode")
map("i", "kj", "<esc>", desc "Exit insert mode")

map("n", "<tab>", "<c-w>", desc "Window navigation prefix")
map("n", "+", "<c-w>+", desc "Window Adjust split height up")
map("n", "_", "<c-w>-", desc "Window Adjust split height down")
map("n", "<leader>]", "<cmd> vert res -1 <cr>", desc "Window Adjust split width right")
map("n", "<leader>[", "<cmd> vert res +1 <cr>", desc "Window Adjust split width left")
map("n", "&", "<cmd> && <cr>", desc "Repeat Last substitute")
map("n", "q<cr>", "q:", desc "Command Enter command window")
unmap("n", "<leader>v")
map("n", "<leader>v", "<cmd> vsp | term <cr><cmd> startinsert <cr>", desc "Terminal Open vertical split")

map("t", "<c-h>", "<cmd> wincmd h <cr>", desc "Terminal Move to left window")
map("t", "<c-j>", "<cmd> wincmd j <cr>", desc "Terminal Move to lower window")
map("t", "<c-k>", "<cmd> wincmd k <cr>", desc "Terminal Move to upper window")
map("t", "<c-l>", "<cmd> wincmd l <cr>", desc "Terminal Move to right window")

map("n", "0", "^", desc "Jump To first non-whitespace character")
map("n", "^", "<home>", desc "Jump To beginning of line")
map("n", "Y", "y$", desc "Yank To end of line")
map("n", "U", "<c-r>", desc "Redo")
map("n", "Q", "@@", desc "Repeat Most recent macro")
map("n", "<leader>cd", "<cmd> cd %:h <cr>", desc "Directory Change Nvim working directory to that of current buffer")
map("v", "il", "^o$h", desc "Visual Inside line")
map("v", "<c-y>", "\"*y", desc "Yank Into system register")
map("n", "<c-p>", "\"*p", desc "Paste From system register")

map("n", "<c-n>", "<cmd> NvimTreeFocus <cr>", desc "NvimTree open or jump to explorer")
map("n", "<c-f>", "<cmd> NvimTreeFindFile <cr>", desc "NvimTree show in explorer ")

map("n", "<leader>l", "<cmd> LspRestart <cr>", desc "LSP Restart")

map("n", "<leader>db", "<cmd> DapToggleBreakpoint <cr>", desc "DAP Toggle Breakpoint")
map("n", "<leader>dn", "<cmd> NvimTreeClose <cr><cmd> DapNew <cr>", desc "DAP New session")
map("n", "<leader>dd", "<cmd> DapDisconnect <cr>", desc "DAP DapDisconnect")
map("n", "<F7>", "<cmd> DapStepOut <cr>", desc "DAP Step out")
map("n", "<F8>", "<cmd> DapStepInto <cr>", desc "DAP Step into")
map("n", "<F9>", "<cmd> DapStepOver <cr>", desc "DAP Step over")
map("n", "<F10>", "<cmd> DapContinue <cr>", desc "DAP Continue")

map("n", "ZZ", "<cmd> :wqa <cr>", desc "Exit Quit Neovim after saving")
map("n", "ZX", "<cmd> :qa! <cr>", desc "Exit Quit Neovim without saving")

map("n", "<leader>tt", "<cmd> Telescope builtin <cr>", desc "Telescope Builtins")
map("n", "<leader>th", "<cmd> Telescope highlights <cr>", desc "Telescope Highlights")
map("n", "<leader>tr", "<cmd> Telescope registers <cr>", desc "Telescope Registers")
map("n", "<leader>tm", "<cmd> Telescope keymaps <cr>", desc "Telescope Mappings")
unmap("n", "<leader>fz")
map("n", "<leader>tf", "<cmd> Telescope current_buffer_fuzzy_find <cr>", desc "Telescope Fuzzy find in current buffer")
map("n", "<leader>fg", "<cmd> Telescope git_files <cr>", desc "Telescope Find files in current git repo")

