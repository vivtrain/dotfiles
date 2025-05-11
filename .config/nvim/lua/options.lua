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

local o = vim.o
-- Do not share unnamed register with system clipboard
o.clipboard = ""
-- Set a marker for keeping lines under 80 characters
o.colorcolumn = "81"
-- Enable CursorLine
-- options.cursorlineopt = 'both'
o.matchpairs = '[:],(:),{:},<:>'

vim.api.nvim_set_hl(0, "@comment.lua", { link = "Comment" })

vim.api.nvim_create_autocmd({ "VimEnter" }, {
  desc = "Open nvim-tree on startup if a buffer is opened (i.e. no NvDash)",
  callback = function()
    if vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf()):len() > 0 then
      require("nvim-tree.api").tree.toggle({ find_file = true, focus = false, })
    end
  end,
})

vim.api.nvim_create_autocmd({'BufWinEnter'}, {
  desc = 'Return cursor to where it was last time closing the file',
  pattern = '*',
  command = 'silent! normal! g`"zv',
})
