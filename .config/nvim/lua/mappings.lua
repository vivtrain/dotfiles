require "nvchad.mappings"

local map = vim.keymap.set
local unmap = vim.keymap.del
local function opts(desc)
  return { desc = desc }
end

unmap("n", "<leader>ch")
map("n", "<leader>ch", "<cmd> NvimTreeClose <cr><cmd> NvCheatsheet <cr>")

map("i", "jk", "<esc>", opts "Exit insert mode")
map("i", "kj", "<esc>", opts "Exit insert mode")

map("n", "<tab>", "<c-w>", opts "Window navigation prefix")
map("n", "+", "<c-w>+", opts "Window Adjust split height up")
map("n", "_", "<c-w>-", opts "Window Adjust split height down")
map("n", "]]", "<cmd> vert res -1 <cr>", opts "Window Adjust split width right")
map("n", "[[", "<cmd> vert res +1 <cr>", opts "Window Adjust split width left")

map({"t","n"}, "<c-p>", "<cmd> wincmd p <cr>", opts "Terminal Return to editor buffer")
map("t", "<c-h>", "<cmd> wincmd h <cr>", opts "Terminal Move to left window")
map("t", "<c-j>", "<cmd> wincmd j <cr>", opts "Terminal Move to lower window")
map("t", "<c-k>", "<cmd> wincmd k <cr>", opts "Terminal Move to upper window")
map("t", "<c-l>", "<cmd> wincmd l <cr>", opts "Terminal Move to right window")

map("n", "0", "^", opts "Jump to first non-whitespace character")
map("n", "^", "<home>", opts "Jump to beginning of line")
map("n", "Y", "y$", opts "Yank to end of line")
map("n", "U", "<c-r>", opts "Redo")
map("n", "Q", "@@", opts "Repeat most recent macro")
map("n", "<leader>cd", "<cmd> cd %:h <cr>", opts "Directory Change Nvim working directory to that of current buffer")
map("v", "il", "^o$h", opts "Visual Inside line")

map("n", "<c-n>", "<cmd> NvimTreeFocus <cr>", opts "NvimTree open or jump to explorer")
map("n", "<c-f>", "<cmd> NvimTreeFindFile <cr>", opts "NvimTree show in explorer ")

map("n", "<leader>l", "<cmd> LspRestart <cr>", opts "LSP Restart")

map("n", "<leader>db", "<cmd> DapToggleBreakpoint <cr>", opts "DAP Toggle Breakpoint")
map("n", "<leader>dn", "<cmd> NvimTreeClose <cr><cmd> DapNew <cr>", opts "DAP New session")
map("n", "<leader>dd", "<cmd> DapDisconnect <cr>", opts "DAP DapDisconnect")
map("n", "<F7>", "<cmd> DapStepOut <cr>", opts "DAP Step out")
map("n", "<F8>", "<cmd> DapStepInto <cr>", opts "DAP Step into")
map("n", "<F9>", "<cmd> DapStepOver <cr>", opts "DAP Step over")
map("n", "<F10>", "<cmd> DapContinue <cr>", opts "DAP Continue")

map("n", "ZZ", "<cmd> :wqa <cr>", opts "Exit Quit Neovim after saving")
map("n", "ZX", "<cmd> :qa! <cr>", opts "Exit Quit Neovim without saving")

map("n", "<leader>tt", "<cmd> Telescope builtin <cr>", opts "Telescope Builtins")
map("n", "<leader>th", "<cmd> Telescope highlights <cr>", opts "Telescope Highlights")
map("n", "<leader>tr", "<cmd> Telescope registers <cr>", opts "Telescope Registers")
map("n", "<leader>tm", "<cmd> Telescope keymaps <cr>", opts "Telescope Mappings")
unmap("n", "<leader>fz")
map("n", "<leader>tf", "<cmd> Telescope current_buffer_fuzzy_find <cr>", opts "Telescope Fuzzy find in current buffer")
map("n", "<leader>fg", "<cmd> Telescope git_files <cr>", opts "Telescope Find files in current git repo")

