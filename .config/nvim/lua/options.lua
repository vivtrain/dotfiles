require "nvchad.options"

local o = vim.o
local g = vim.g
local api = vim.api

-- Setup WSL clipboard
g.clipboard = {
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
g.python_recommended_style = 0;
o.clipboard = ""
o.colorcolumn = "81"
o.matchpairs = '[:],(:),{:},<:>'

-- Override Treesitter/Base46 colorschemes
vim.schedule(function ()
  api.nvim_set_hl(0, "@comment", { link = "Comment" })
end)

vim.fn.sign_define("DapBreakpoint", {text='', texthl='DapBreakpoint', linehl='', numhl=''});

api.nvim_create_autocmd({ "VimEnter" }, {
  desc = "Open nvim-tree on startup",
  callback = function()
    local bufName = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
    local baseName = vim.fs.basename(bufName)
    local winWidth = vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())
    -- Do not open if empty buffer (i.e. NvDash should show)
    -- or if doing a commit message
    -- or if window is narrow
    if bufName:len() > 0 and baseName ~= "COMMIT_EDITMSG" and winWidth > 120 then
      require("nvim-tree.api").tree.toggle({ find_file = true, focus = false, })
    end
  end,
})
api.nvim_create_autocmd({'BufWinEnter'}, {
  desc = 'Return cursor to where it was last time closing the file',
  pattern = '*',
  command = 'silent! normal! g`"zv',
})
api.nvim_create_autocmd({'CmdwinEnter'}, {
  desc = 'Exit cmd window using <esc>',
  command = 'nmap <esc> :q<cr>',
})
api.nvim_create_autocmd({'WinEnter','BufWinEnter'}, {
  desc = 'Always be in insert mode when entering a terminal window',
  pattern = 'term://*',
  command = 'startinsert',
})

