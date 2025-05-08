-- load defaults
require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"
local nvlsp = require "nvchad.configs.lspconfig"

-- configuring single server, example: typescript
-- lspconfig.tsserver.setup {
--   on_attach = nvlsp.on_attach,
--   on_init = nvlsp.on_init,
--   capabilities = nvlsp.capabilities,
-- }

lspconfig.lua_ls.setup({
  cmd = {"lua-language-server"},
  filetypes = {"lua"},
  root_dir = lspconfig.util.root_pattern(
    "~/.local/share/nvim/lazy/nvim-lspconfig/.luarc.json",
    "~/.local/share/nvim/lazy/nvim-lspconfig/.luarc.jsonc",
    "~/.local/share/nvim/lazy/nvim-lspconfig/.luacheckrc",
    "~/.local/share/nvim/lazy/nvim-lspconfig/.stylua.toml",
    "~/.local/share/nvim/lazy/nvim-lspconfig/stylua.toml",
    "~/.local/share/nvim/lazy/nvim-lspconfig/selene.toml",
    "~/.local/share/nvim/lazy/nvim-lspconfig/selene.yml",
    "~/.local/share/nvim/lazy/nvim-lspconfig/.git"),
  single_file_support = true
})

lspconfig.pyright.setup({
  on_init = nvlsp.on_init,
  on_attach = nvlsp.on_attach,
  capabilities = nvlsp.capabilities,
  filetypes = { "python" },
})

lspconfig.clangd.setup({
  on_init = nvlsp.on_init,
  on_attach = nvlsp.on_attach,
  capabilities = nvlsp.capabilities,
  filetypes = { "cpp", "c", "cc", "h", "tpp", "mpp" },
})

lspconfig.ts_ls.setup({
  on_init = nvlsp.on_init,
  on_attach = nvlsp.on_attach,
  capabilities = nvlsp.capabilities,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
})

lspconfig.tailwindcss.setup({
  on_init = nvlsp.on_init,
  on_attach = nvlsp.on_attach,
  capabilities = nvlsp.capabilities,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
})

lspconfig.eslint.setup({
  on_init = nvlsp.on_init,
  on_attach = nvlsp.on_attach,
  capabilities = nvlsp.capabilities,
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
})

lspconfig.cssls.setup({
  on_init = nvlsp.on_init,
  on_attach = nvlsp.on_attach,
  capabilities = nvlsp.capabilities,
})

