local M = {}

function M.is_template()

  local line = vim.api.nvim_get_current_line()
  local r, c = unpack(vim.api.nvim_win_get_cursor(0))
  if not (vim.o.filetype == "cpp" or vim.o.filetype == "c") then
    line = line:sub(1, c) .. "<" .. line:sub(c + 1)
    vim.api.nvim_set_current_line(line)
    vim.api.nvim_win_set_cursor(0, { r, c + 1 })
    return
  end

  if vim.fn.match({ line }, "template") == 0 then
    line = line:sub(1, c) .. "<>" .. line:sub(c + 1)
    vim.api.nvim_set_current_line(line)
    vim.api.nvim_win_set_cursor(0, { r, c + 1 })
    return
  end

  if vim.fn.match({ line }, "#include") == 0 then
    line = line:sub(1, c) .. "<>" .. line:sub(c + 1)
    if line:sub(c, c) ~= " " then
      line = line:sub(1, c) .. " " .. line:sub(c + 1)
      c = c + 1
    end
    vim.api.nvim_set_current_line(line)
    vim.api.nvim_win_set_cursor(0, { r, c + 1 })
    return
  end
  if vim.fn.match({ line:sub(0, c) }, "cast\\s*$") == 0 then
    -- c - 1 = 2 chars before the cursor
    line = line:sub(1, c) .. "<>" .. line:sub(c + 1)
    vim.api.nvim_set_current_line(line)
    vim.api.nvim_win_set_cursor(0, { r, c + 1 })
    return
  end


  line = line:sub(1, c) .. "<" .. line:sub(c + 1)
  vim.api.nvim_set_current_line(line)
  vim.api.nvim_win_set_cursor(0, { r, c + 1 })
  vim.cmd("redraw") -- redraw to add the first <

  local old_handler = vim.lsp.handlers["textDocument/signatureHelp"]
  vim.lsp.handlers["textDocument/signatureHelp"] = function(_, info)
    if info and info.signatures and info.signatures[1] and info.signatures[1].label then
      local functionsig = info.signatures[1].label
      if vim.fn.match({ functionsig }, "^\\w\\+<") == 0 then
        -- c + 1 is after including the openning pair very shady code lol
        vim.api.nvim_set_current_line(line:sub(0, c + 1) .. ">" .. line:sub(c + 2))
      end
    end
  end
  vim.lsp.buf.signature_help()
  vim.lsp.handlers["textDocument/signatureHelp"] = old_handler
end

function M.struct_class_semicolon()
  local function match(str, pat)
    return vim.fn.match(str, pat) ~= -1
  end

  local line = vim.api.nvim_get_current_line()
  local probablySTL = "vector\\|map\\|pair\\|tuple\\|set\\|array\\|list\\|stack\\|queue"

  local structOrClass = match(line, "struct\\|class")
  local stlInitializer = match(line, probablySTL)
      and not match(line, "{") and not match(line, "(")

  local row = vim.api.nvim_win_get_cursor(0)[1]
  local prevLine = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
  if not structOrClass then
    while row > 0 and match(prevLine, "^\\s*$") do
      row = row - 1
      prevLine = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
    end
  end

  local prevStructOrClass = match(prevLine, "struct\\|class")
  local prevStlInitializer = match(prevLine, probablySTL)
      and not match(prevLine, "{") and not match(prevLine, "(")

  return structOrClass or prevStructOrClass
    or stlInitializer or prevStlInitializer

end

return M
