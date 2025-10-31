local M = {}
local function printTable(tbl)
  io.write '{'
  for k, v in pairs(tbl) do
    io.write(k .. ' = ')
    if type(v) == 'table' then
      printTable(v)
    else
      io.write(tostring(v))
    end
    io.write ', '
  end
  io.write '}'
end

-- Creates a buffer, sets its name to its `URI`, and `:edit`s the name (thus opening the uri)
--
---@param uri lsp.URI
---@return integer bufNum
local function createAndFillBufferByUri(uri)
  local bufNum = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(bufNum, uri)
  vim.api.nvim_buf_call(bufNum, vim.cmd.edit)

  return bufNum
end

M.setup = function()
  print 'I am the setup function of expandable hover!'
end

---@param text string[]
---@param fileType string
M.openCuteWindow = function(text, fileType)
  -- Create a temporary buffer
  local tempBufId = vim.api.nvim_create_buf(true, true)
  if tempBufId == nil then
    print 'Error creating window buffer'
    return
  end

  vim.api.nvim_set_option_value('filetype', fileType, { buf = tempBufId })
  vim.api.nvim_buf_set_lines(tempBufId, 0, -1, true, text)
  vim.lsp.buf_attach_client(tempBufId, 1) -- Tell the current LSP, it should look on this buffer too

  -- treesitter
  vim.treesitter.start(tempBufId)

  -- Open a window
  vim.api.nvim_open_win(tempBufId, true, {
    title = '  Expandable Hover  ',
    footer = string.format('  %s  ', fileType),
    footer_pos = 'right',
    border = 'double',
    height = 8,
    width = 80,
    bufpos = { 1, 1 },
    relative = 'cursor',
  })
end

M.callLspHover = function()
  vim.lsp.buf_request(0, 'textDocument/hover', vim.lsp.util.make_position_params(0, 'utf-8'), function(err, result)
    if err then
      print "Couldn't call textDocument/hover! :("
      printTable(err)
      return
    elseif result == nil then
      print 'No Info'
      return
    end

    local fileType = vim.api.nvim_get_option_value('filetype', {})
    local lspHoverResult = {}
    for line in string.gmatch(result.contents.value, '[^\n]+') do
      if line == '```' then
        break
      elseif line.find(line, '```') then
        goto continue
      end
      table.insert(lspHoverResult, line)
      ::continue::
    end

    M.openCuteWindow(lspHoverResult, fileType)
  end)
end

M.callLspDefinition = function()
  vim.lsp.buf_request(0, 'textDocument/definition', vim.lsp.util.make_position_params(0, 'utf-8'), function(err, result)
    if err then
      printTable(err)
      return
    end

    local uri = result[1].targetUri
    printTable(result)

    local newBufNum = createAndFillBufferByUri(uri)
  end)
end

return M
