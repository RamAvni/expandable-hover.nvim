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

local function getMainBuf()
  local callerBufId = vim.api.nvim_get_current_buf()
  local isNotMainBuf, callersMainBufIdVar = pcall(vim.api.nvim_buf_get_var, callerBufId, 'mainBufId')

  if isNotMainBuf then
    return callersMainBufIdVar
  else
    return callerBufId
  end
end

---@param uri lsp.URI
---@return integer bufNum
local function createAndFillBufferByUri(uri)
  local currentBufId = vim.api.nvim_get_current_buf()
  local absolutePath = string.gsub(string.format('%s', uri), 'file://', '') -- Turn `uri` into a raw string, then remove 'file://'
  local name = string.format('expandable-hover: %s', absolutePath)
  if vim.api.nvim_buf_get_name(0) == absolutePath then
    return currentBufId
  elseif vim.fn.bufexists(name) == 1 then
    error 'buffer already exists!'
  end

  local fileContent = vim.fn.system { 'cat', string.gsub(absolutePath, 'file://', '') }
  local lines = vim.split(fileContent, '\n')

  local bufNum = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_name(bufNum, name)
  vim.api.nvim_buf_set_lines(bufNum, 0, -1, true, lines)

  return bufNum
end

M.setup = function()
  print 'I am the setup function of expandable hover!'
end

---@param text string[]
---@param mainBufId integer
M.openCuteWindow = function(text, mainBufId)
  local mainLspClients = vim.lsp.get_clients { bufnr = mainBufId }
  local mainBufFileType = vim.api.nvim_get_option_value('filetype', { buf = mainBufId })
  -- Create a temporary buffer
  local tempBufId = vim.api.nvim_create_buf(true, true)
  if tempBufId == nil then
    print 'Error creating window buffer'
    return
  end

  vim.api.nvim_set_option_value('filetype', mainBufFileType, { buf = tempBufId })
  vim.api.nvim_buf_set_var(tempBufId, 'mainBufId', mainBufId)
  vim.api.nvim_buf_set_lines(tempBufId, 0, -1, true, text)

  -- Attach LSPs to the new window-buffer
  for _, lspClient in ipairs(mainLspClients) do
    vim.lsp.buf_attach_client(tempBufId, lspClient.id)
  end

  -- treesitter
  vim.treesitter.start(tempBufId)

  -- Open a window
  local tempWinId = vim.api.nvim_open_win(tempBufId, true, {
    title = '  Expandable Hover  ',
    footer = string.format('  %s  ', mainBufFileType),
    footer_pos = 'right',
    border = 'double',
    height = 8,
    width = 80,
    bufpos = { 1, 1 },
    relative = 'cursor',
  })

  -- -- Cleanup
  -- vim.api.nvim_create_autocmd({ 'bufEnter' }, {
  --   buffer = mainBufId,
  --   once = true,
  --   callback = function()
  --     vim.api.nvim_win_close(tempWinId, false)
  --     vim.api.nvim_buf_delete(tempBufId, {})
  --   end,
  -- })
end

M.callLspHover = function()
  local mainBufId = getMainBuf()

  vim.lsp.buf_request(mainBufId, 'textDocument/hover', vim.lsp.util.make_position_params(0, 'utf-8'), function(err, result)
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

    M.openCuteWindow(lspHoverResult, mainBufId)
  end)
end

M.callLspDefinition = function()
  local mainBufId = getMainBuf()

  vim.lsp.buf_request(mainBufId, 'textDocument/definition', vim.lsp.util.make_position_params(0, 'utf-8'), function(err, result)
    if err then
      printTable(err)
      return
    elseif result == nil then
      print 'No Info'
      return
    end

    result = result ---@type lsp.LocationLink[] -- move this type somewhere else this is uglyyyyyyyyyyyy
    local uri = result[1].targetUri
    local targetRange = result[1].targetRange

    local newBufNum = createAndFillBufferByUri(uri)
    local lines = vim.api.nvim_buf_get_lines(newBufNum, targetRange.start.line, targetRange['end'].line + 1, false)
    M.openCuteWindow(lines, mainBufId)

    -- Cleanup: removing newly created buffers
    if newBufNum ~= vim.api.nvim_get_current_buf() then
      vim.api.nvim_buf_delete(newBufNum, {})
    end
  end)
end

return M

-- TODO: M.openCuteWindow does not close un-focused buffers. leading to same-name buffers
-- TODO: temp buffer function
