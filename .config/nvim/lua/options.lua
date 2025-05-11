require "nvchad.options"

-- Setup WSL clipboard
vim.g.clipboard = {
  name = "clip-wsl",
  copy = {
    ["+"] = "clip.exe",
    ["*"] = "clip.exe",
  },
  paste = {
    ['+'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
    ['*'] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
  },
  cache_enabled = true,
}

local options = vim.o
-- Do not share unnamed register with system clipboard
options.clipboard = ""
-- Set a marker for keeping lines under 80 characters
options.colorcolumn = "81"
-- Enable CursorLine
-- options.cursorlineopt = 'both'

vim.api.nvim_set_hl(0, "@comment.lua", { link = "Comment" })

vim.api.nvim_create_autocmd({
  "VimEnter" },
  { callback = function()
    require("nvim-tree.api").tree.open()
  end,
})

