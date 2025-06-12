return {

  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
  	"nvim-treesitter/nvim-treesitter",
  	opts = {
  		ensure_installed = {
  			"vim", "lua", "vimdoc", "cpp", "python", "html", "javascript",
        "typescript", "tsx", "css",
  		},
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting=true,
      },
      indent = {
        enable = false,
      },
  	},
  },

  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup {}
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    tag = "0.1.8",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        "clangd",
        "clang-format",
        "codelldb",
        "pyright",
        "mypy",
        "ruff",
        "eslint-lsp",
        "typescript-language-server",
        "tailwindcss-language-server",
      },
    },
  },

  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter" },
    config = function ()
      local cmp = require("cmp")
      local defaults = require("nvchad.configs.cmp")
      local options = {
        completion = { completeopt = "menu,menuone,noinsert,noselect" },
        window = {
          completion = cmp.config.window.bordered({
            border = 'single',
            winhighlight = 'Normal:CmpPmenu,FloatBorder:CmpBorder,CursorLine:CmpSel'
          }),
          documentation = cmp.config.window.bordered({
            border = 'rounded',
            winhighlight = 'Normal:CmpPmenu,FloatBorder:FloatBorder'
          }),
        },
        mapping = {
          ["<CR>"] = cmp.mapping(function(fallback)
            if cmp.visible() and cmp.get_active_entry() then
              local curNodes = require("luasnip.session").current_nodes
              local nodeBefore = curNodes[vim.api.nvim_get_current_buf()]
              cmp.mapping.confirm({
                behavior = cmp.ConfirmBehavior.Insert,
                select = true,
              })()
              vim.schedule(function()
              local nodeAfter = curNodes[vim.api.nvim_get_current_buf()]
                if nodeBefore and nodeAfter and nodeBefore == nodeAfter then
                  require("luasnip").jump(1)
                end
              end)
            else
              fallback()
            end
          end)
        },
      }
      options = vim.tbl_deep_extend("force", defaults, options)
      cmp.setup(options)
    end,
  },

  {
    "windwp/nvim-autopairs",
    dependencies = {
      { "hrsh7th/nvim-cmp" },
    },
    event = "InsertEnter",
    opts = {
      fast_wrap = {},
      disable_filetype = { "TelescopePrompt", "vim" },
    },
    config = function(_, opts)
      local npairs = require("nvim-autopairs")
      local rule = require("nvim-autopairs.rule")
      local cond = require("nvim-autopairs.conds")

      npairs.setup(opts)

      local is_template = require("util.cpair").is_template
      local semicolon = require("util.cpair").struct_class_semicolon
      npairs.add_rules({
        rule("<", ">"):with_pair(cond.none()):with_move(cond.done()):use_key(">"),
        rule("{", "};", { "cpp", "c" }):with_pair(semicolon),
      })
      vim.keymap.set("i", "<", is_template)

      -- setup cmp for autopairs
      local cmp_autopairs = require "nvim-autopairs.completion.cmp"
      require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end,
  },

  { "williamboman/mason-lspconfig.nvim" },

  { "mfussenegger/nvim-dap", },

  {
    "jay-babu/mason-nvim-dap.nvim",
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
    },
    opts = {
      handlers = {},
      ensure_installed = {
        "codelldb",
      },
    },
  },

  { "nvim-neotest/nvim-nio", },

  {
    "rcarriga/nvim-dap-ui",
    event = "VeryLazy",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    config = function ()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function ()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function ()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function ()
        dapui.close()
      end
    end
  },

  {
    "windwp/nvim-ts-autotag",
    ft = {
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "html",
    },
    config = function ()
      require("nvim-ts-autotag").setup()
    end
  },

  {
    "kylechui/nvim-surround",
    version = "^3.0.0", -- Use for stability; omit to use `main` branch for the latest features
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({
          -- Configuration here, or leave empty to use defaults
      })
    end
  },

  {
    "chentoast/marks.nvim",
    event = "VeryLazy",
    opts = {
      -- which builtin marks to show. default {}
      builtin_marks = { "<", ">", "^", "'" },
      -- whether movements cycle back to the beginning/end of buffer. default true
      cyclic = true,
      -- whether the shada file is updated after modifying uppercase marks. default false
      force_write_shada = false,
      -- how often (in ms) to redraw signs/recompute mark positions. 
      -- higher values will have better performance but may cause visual lag, 
      -- while lower values may cause performance penalties. default 150.
      refresh_interval = 150,
      -- sign priorities for each type of mark - builtin marks, uppercase marks, lowercase
      -- marks, and bookmarks.
      -- can be either a table with all/none of the keys, or a single number, in which case
      -- the priority applies to all marks.
      -- default 10.
      sign_priority = { lower=10, upper=15, builtin=8, bookmark=20 },
      -- disables mark tracking for specific filetypes. default {}
      excluded_filetypes = {},
      -- disables mark tracking for specific buftypes. default {}
      excluded_buftypes = { "prompt", "nofile" },
      -- marks.nvim allows you to configure up to 10 bookmark groups, each with its own
      -- sign/virttext. Bookmarks can be used to group together positions and quickly move
      -- across multiple buffers. default sign is '!@#$%^&*()' (from 0 to 9), and
      -- default virt_text is "".
      bookmark_0 = {
        sign = "⚑",
        virt_text = "hello world"
      },
      mappings = {}
    }
  },

}
