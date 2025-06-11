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
  api.nvim_set_hl(0, "@lsp.type.operator.cpp", {}) -- disable this
end)
-- Lower semantic token highlight priorities
-- vim.highlight.priorities.semantic_tokens = 75

vim.fn.sign_define("DapBreakpoint", {text='', texthl='DapBreakpoint', linehl='', numhl=''});

api.nvim_create_autocmd({ "VimEnter" }, {
  desc = "Open nvim-tree on startup",
  callback = function()
    local bufName = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
    local baseName = vim.fs.basename(bufName)
    -- Do not open if empty buffer (NvDash)
    if bufName:len() == 0
        or baseName:find("COMMIT_EDITMSG", 0, true)
        or baseName:find("bash-fc", 0, true) then
      return
    end

    local winWidth = vim.api.nvim_win_get_width(vim.api.nvim_get_current_win())
    -- Do not open if narrow window
    if winWidth > 120 then
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
  command = 'nmap <buffer> <esc> :q<cr>',
})
api.nvim_create_autocmd({'WinEnter','BufWinEnter'}, {
  desc = 'Always be in insert mode when entering a terminal window',
  pattern = 'term://*',
  command = 'startinsert',
})

