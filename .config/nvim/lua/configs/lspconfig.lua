local lspconfig = require "lspconfig"
local nvlsp = require "nvchad.configs.lspconfig"

local function custom_nv_defaults()
  dofile(vim.g.base46_cache .. "lsp")
  require("nvchad.lsp").diagnostic_config()
  local map = vim.keymap.set
  local on_attach = function(_, bufnr)
    local function opts(desc)
      return { buffer = bufnr, desc = "LSP " .. desc }
    end

    map("n", "gD", vim.lsp.buf.declaration, opts "Go to declaration")
    map("n", "gd", vim.lsp.buf.definition, opts "Go to definition")
    map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts "Add workspace folder")
    map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts "Remove workspace folder")

    map("n", "<leader>wl", function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, opts "List workspace folders")

    map("n", "<leader>D", vim.lsp.buf.type_definition, opts "Go to type definition")
    map("n", "<c-space>", vim.diagnostic.open_float, opts "LSP Open float window")
    local function rename()
      require('nvchad.lsp.renamer')({
        border = "rounded",
        border_hl_group = "FloatBorder",
        right_padding = 15,
        title = "rename symbol",
        title_hl_group = "@comment.note",
        mode = "normal",
        show_original = true,
      })
    end
    map("n", "<F2>", rename, opts "LSP Rename variable")
    map("n", "<leader>ra", rename, opts "LSP Rename variable")
    map("n", "<leader>ca", vim.lsp.buf.code_action, opts "LSP Code action")
  end

  vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
      on_attach(_, args.buf)
    end,
  })

  local lua_lsp_settings = {
    Lua = {
      workspace = {
        library = {
          vim.fn.expand "$VIMRUNTIME/lua",
          vim.fn.stdpath "data" .. "/lazy/ui/nvchad_types",
          vim.fn.stdpath "data" .. "/lazy/lazy.nvim/lua/lazy",
          "${3rd}/luv/library",
        },
      },
    },
  }

  -- Support 0.10 temporarily

  if vim.lsp.config then
    vim.lsp.config("*", { capabilities = nvlsp.capabilities, on_init = nvlsp.on_init })
    vim.lsp.config("lua_ls", { settings = lua_lsp_settings })
    vim.lsp.enable "lua_ls"
  else
    require("lspconfig").lua_ls.setup {
      capabilities = nvlsp.capabilities,
      on_init = nvlsp.on_init,
      settings = lua_lsp_settings,
    }
  end
end

custom_nv_defaults()

lspconfig.pyright.setup({
  filetypes = { "python" },
})

lspconfig.clangd.setup({
  filetypes = { "cpp", "c", "cc", "h", "tpp", "mpp" },
})

lspconfig.ts_ls.setup({
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
})

lspconfig.tailwindcss.setup({
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
})

lspconfig.eslint.setup({
  filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
  },
})

lspconfig.cssls.setup({
})

