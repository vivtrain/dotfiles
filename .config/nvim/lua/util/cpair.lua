local M = {}

function M.is_template()

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
  local r, c = unpack(vim.api.nvim_win_get_cursor(0))
  if not (vim.o.filetype == "cpp" or vim.o.filetype == "c") then
    line = line:sub(1, c) .. "<" .. line:sub(c + 1)
    -- vim.api.nvim_set_current_line(line)
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, {line})
    vim.api.nvim_win_set_cursor(win, { r, c + 1 })
    return
  end

  if vim.fn.match({ line }, "template") == 0 then
    line = line:sub(1, c) .. "<>" .. line:sub(c + 1)
    -- vim.api.nvim_set_current_line(line)
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, {line})
    vim.api.nvim_win_set_cursor(win, { r, c + 1 })
    return
  end

  if vim.fn.match({ line }, "#include") == 0 then
    line = line:sub(1, c) .. "<>" .. line:sub(c + 1)
    if line:sub(c, c) ~= " " then
      line = line:sub(1, c) .. " " .. line:sub(c + 1)
      c = c + 1
    end
    -- vim.api.nvim_set_current_line(line)
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, {line})
    vim.api.nvim_win_set_cursor(win, { r, c + 1 })
    return
  end
  if vim.fn.match({ line:sub(0, c) }, "cast\\s*$") == 0 then
    -- c - 1 = 2 chars before the cursor
    line = line:sub(1, c) .. "<>" .. line:sub(c + 1)
    -- vim.api.nvim_set_current_line(line)
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, {line})
    vim.api.nvim_win_set_cursor(win, { r, c + 1 })
    return
  end


  line = line:sub(1, c) .. "<" .. line:sub(c + 1)
  -- vim.api.nvim_set_current_line(line)
  vim.api.nvim_buf_set_lines(buf, row - 1, row, false, {line})
  vim.api.nvim_win_set_cursor(win, { r, c + 1 })
  vim.cmd("redraw") -- redraw to add the first <

  local old_handler = vim.lsp.handlers["textDocument/signatureHelp"]
  vim.lsp.handlers["textDocument/signatureHelp"] = function(_, info)
    if info and info.signatures and info.signatures[1] and info.signatures[1].label then
      local functionsig = info.signatures[1].label
      if vim.fn.match({ functionsig }, "^\\w\\+<") == 0 then
        -- c + 1 is after including the openning pair very shady code lol
        line = line:sub(0, c + 1) .. ">" .. line:sub(c + 2)
        vim.api.nvim_buf_set_lines(buf, row - 1, row, false, {line})
      end
    end
  end
  vim.lsp.buf.signature_help()
  vim.lsp.handlers["textDocument/signatureHelp"] = old_handler
end

function M.struct_class_semicolon()
  -- Convenience for finding patterns
  local function match(str, pat)
    return vim.fn.match(str, pat) ~= -1
  end

  -- Patterns to check against
  local structOrClassPattern = "struct\\|class"
  local probablySTLPattern =
    "vector\\|map\\|pair\\|tuple\\|set\\|array\\|list\\|stack\\|queue"
  local parensPattern = "(\\|{"

  -- Current line checks
  local line = vim.api.nvim_get_current_line()
  local structOrClass = match(line, structOrClassPattern)
  local stlInitializer = match(line, probablySTLPattern)
  local parens = match(line, parensPattern)

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
  local prevParens = match(prevLine, parensPattern)

  local isStructOrClass = (structOrClass and not parens)
    or (prevStructOrClass and not prevParens)
  local isStl = (stlInitializer and not parens)
    or (prevStlInitializer and not prevParens)

  return isStructOrClass or isStl

end

return M
