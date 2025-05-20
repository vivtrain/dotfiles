-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local config = {}

config.base46 = {
  changed_themes = {
    catppuccin = {
      base_30 = {
        red = "#F38ba8",
        light_grey = "#808090",
        grey = "#505060",
        black = "#202025",
        darker_black = "#16161A",
      },
    }
  },
	theme = "catppuccin",
	hl_override = {
	  Normal = { bg = "NONE" },
    LineNr = { fg = "light_grey" },
    CursorLineNr = { fg = "white" },
    WinSeparator = { fg = "light_grey" },
    Comment = { fg = "light_grey" },
    CmpPmenu = { bg = "darker_black" },
    CmpBorder = { fg = "grey", bg = "darker_black" },
    NvDashFooter = { fg = "green" },
    NvimTreeRootFolder = { fg = "purple" },
    NvDashAscii = { fg = "blue" },
    NvDashButtons = { fg = "purple" },
    Visual = { bg = { "grey", 1 } },
  },
  hl_add = {
    DapBreakpoint = { fg = "red" },
    MarkSignHL = { fg = "cyan" },
    MarkSignNumHL = { fg = "cyan" },
  }
}

config.ui = {
  statusline = { separator_style = "default" },
  tabufline = { lazyload = false },
  nvdash = { load_on_startup = true, },
  renamer = {
    border = "rounded",
    border_hl_group = "FloatBorder",
    mode = "normal",
    title = "Rename Symbol",
    title_hl_group = "@comment.note",
    show_original = true,
  }
}

config.nvdash = {
  load_on_startup = true,
  header = {
    "                                                      ",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣠⡴⡢⡶⠶⢢⢄⠀⠀⠀⠀                              ",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢾⣾⣟⠝⠀  ⢹⡏⠀⠀⠀     ▄▄         ▄ ▄▄▄▄▄▄▄▄▄   ",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⣻⡇⠘⠿⢾⢐⣶⠃⠀⠀⠀   ▄▀███▄     ▄██ ███████▀    ",
    "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣱⣾⣷⣦⣠⡾⣃⡐⠀⠀⠀⠀   ██▄▀███▄   ███             ",
    "⠀⠀⠀⠀⠀⣀⡀⣀⣀⣤⣤⣠⡟⢻⣿⣿⣏⠻⡿⠀⠀⠀⠀⠀   ███  ▀███▄ ███             ",
    "⠀⣠⡾⢿⡿⠿⠿⢿⣻⣿⡋⠉⡇⠀⣿⠛⠻⠿⢇⠀⠀⠀⠀⠀   ███    ▀██ ███             ",
    "⣸⠋⠀⣿⠀⠀⠀⠀⠈⠙⢷⠀⢰⣰⠃⡠⢔⠄⠀⠀⢄⠀⠀⠀   ███      ▀ ███             ",
    "⢻⡄⠀⠛⢆⠀⠀⠀⠀⠀⠈⢿⣿⣿⠞⠛⠉⠁⠉⠢⡀⠑⢀⠀   ▀██ ▄████▄▀█▀▄████████▄    ",
    "⠀⢻⢀⢿⣷⠀⠀⠀⠀ ⠀⢸⡟⠀⠀⠀⠀⠀⠀⠀⠈⠆⠀⠡     ▀ ▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀▀▀   ",
    "  ⠀⠀⢻⣿⣄⡀⠀⢀⣾⡏⠀⠀⠀⠀  ⠀⢀⢰⡴⠀⠘⠀                             ",
    "⠀⠀⠀⠀⠀⣿⡝⣻⣿⣿⣿⣿⣦⣄⡀  ⠀⢔⡵⡟⡇⠱⠈⡄  █▄ █ █ █  ▄▀▀ █▄█ ▄▀▄ █▀▄  ",
    "⠀⠀⠀⠀⠀⣾⣹⡯⠤⢄⣏⣀⡈⣹⡟⡩⢋⢼⡄⢹⠀⠀⠌⠀⠇  █ ▀█ ▀▄▀  ▀▄▄ █ █ █▀█ █▄▀  ",
    "      ᴩᴏᴡᴇʀᴇᴅ ʙy  𝗇𝖾𝗈                               ",
    "                                                      ",
  },
}

config.term = {
  base46_colors = false,
  float = { border = "double" },
}

return config

