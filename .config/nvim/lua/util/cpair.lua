local M = {}

---Convenience function for finding a pattern match
---@param str string
---@param pattern string
---@return boolean
local function match(str, pattern)
  return vim.fn.match(str, pattern) ~= -1
end

---Convenience function to combine patterns using logical or
---@param ... string
---@return string
local function orPat(...)
  local pat = ""
  for i,v in ipairs({...}) do
    pat = i == 1 and v or pat .. "\\|" .. v
  end
  return pat
end

function M.complete_angle()

  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local row = vim.api.nvim_win_get_cursor(win)[1]
  local col = vim.api.nvim_win_get_cursor(win)[2]
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]

  local function open()
    line = line:sub(1, col) .. "<" .. line:sub(col + 1)
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, {line})
    vim.api.nvim_win_set_cursor(win, { row, col + 1 })
  end

  local function close()
    line = line:sub(1, col + 1) .. ">" .. line:sub(col + 2)
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, {line})
    vim.api.nvim_win_set_cursor(win, { row, col + 1 })
  end

  if not (vim.o.filetype == "cpp" or vim.o.filetype == "c") then
    open()
    return
  end

  if match(line, orPat("template", "#include", "cast\\s*$")) then
    open()
    close()
    return
  end

  open()
  vim.cmd("redraw") -- redraw to add the first <

  local old_handler = vim.lsp.handlers["textDocument/signatureHelp"]
  vim.lsp.handlers["textDocument/signatureHelp"] = function(_, info, _, _)
    if info and info.signatures and info.signatures[1]
        and info.signatures[1].label then
      local functionsig = info.signatures[1].label
      if vim.fn.match({ functionsig }, "^\\w\\+<") == 0 then
        -- c + 1 is after including the openning pair very shady code lol
        close()
      end
    end
  end
  local encoding = vim.api.nvim_get_option_value("fileencoding", {})
  local util = require('vim.lsp.util')
  local positionParams = util.make_position_params(win, encoding)
  vim.lsp.buf_request(buf, "textDocument/signatureHelp", positionParams)
  vim.lsp.handlers["textDocument/signatureHelp"] = old_handler
end

function M.should_add_semicolon()

  -- Patterns to check against
  local abortPattern = orPat("(",")","{","}",";")
  local structOrClassPattern = orPat("struct", "class", "enum")
  local probablySTLPattern
    = orPat("vector","map","pair","tuple","set","array","list","stack","queue")

  -- Current line checks
  local line = vim.api.nvim_get_current_line()
  local structOrClass = match(line, structOrClassPattern)
  local stlInitializer = match(line, probablySTLPattern)
  local parens = match(line, abortPattern)

  -- Find previous non-whitespace line
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local prevLine = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
  if not structOrClass then
    while row > 0 and match(prevLine, "^\\s*$") do
      row = row - 1
      prevLine = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
    end
  end

  -- Previous (non-whitespace) checks
  local prevStructOrClass = match(prevLine, structOrClassPattern)
  local prevStlInitializer = match(prevLine, probablySTLPattern)
  local prevParens = match(prevLine, abortPattern)

  local isStructOrClass = (structOrClass and not parens)
    or (prevStructOrClass and not (parens or prevParens))
  local isStl = (stlInitializer and not parens)
    or (prevStlInitializer and not (parens or prevParens))

  return isStructOrClass or isStl

end

return M
