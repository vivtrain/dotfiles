vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "

-- nvim 0.12 removed the Query:iter_matches "all" shim, so legacy
-- nvim-treesitter predicates pass a list of nodes where get_node_text expects
-- one TSNode. Normalize before delegating. Drop when NvChad/treesitter migrate.
local _orig_get_node_text = vim.treesitter.get_node_text
function vim.treesitter.get_node_text(node, source, opts)
  if type(node) == "table" then node = node[1] end
  return _orig_get_node_text(node, source, opts)
end

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "nvchad.autocmds"
require "options"

vim.schedule(function()
  require "mappings"
end)

