-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local options = {}

options.base46 = {
	theme = "catppuccin",
	hl_override = {
	  Normal = { bg = "NONE" },
    CursorLine = { bg = "#101010" },
    CmpPmenu = { bg = "#202020" },
  },
}

options.ui = {
  statusline = { separator_style = "default" },
  tabufline = { lazyload = false },
  nvdash = { load_on_startup = true, }
}

options.nvdash = {
  load_on_startup = true,
  header = {
    "                            ",
    "     ▄▄         ▄ ▄▄▄▄▄▄▄   ",
    "   ▄▀███▄     ▄██ █████▀    ",
    "   ██▄▀███▄   ███           ",
    "   ███  ▀███▄ ███           ",
    "   ███    ▀██ ███           ",
    "   ███      ▀ ███           ",
    "   ▀██ █████▄▀█▀▄██████▄    ",
    "     ▀ ▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀   ",
    "                            ",
    " █▄ █ █ █   ▄▀▀ █▄█ ▄▀▄ █▀▄ ",
    " █ ▀█ ▀▄▀   ▀▄▄ █ █ █▀█ █▄▀ ",
    "                            ",
    "    ᴩᴏᴡᴇʀᴇᴅ ʙy   𝗇𝖾𝗈𝗏𝗂𝗆    ",
    "                            ",
  },
}

options.term = {
  base46_colors = false,
  float = { border = "double" },
}

return options

