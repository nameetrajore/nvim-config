-- Open files with the Windows application registered for their type.
local function open_native(path, is_current_buffer)
  if path == '' then
    vim.notify('No file to open', vim.log.levels.WARN)
    return
  end

  path = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
  if not vim.uv.fs_stat(path) then
    vim.notify('File not found: ' .. path, vim.log.levels.ERROR)
    return
  end

  if is_current_buffer and vim.bo.modified then
    vim.notify('Opening saved version; current buffer has unsaved changes', vim.log.levels.WARN)
  end

  local _, err = vim.ui.open(path)
  if err then
    vim.notify(('Could not open %s: %s'):format(path, err), vim.log.levels.ERROR)
  else
    vim.notify('Opened: ' .. path)
  end
end

-- :Open opens the current buffer, or a specified path with file completion.
vim.api.nvim_create_user_command('Open', function(opts)
  local path = opts.args ~= '' and opts.args or vim.api.nvim_buf_get_name(0)
  open_native(path, opts.args == '')
end, {
  nargs = '?',
  complete = 'file',
  desc = 'Open a file in its default Windows application',
})

-- <Space>xo opens the current file in Explorer, its default editor, etc.
vim.keymap.set('n', '<leader>xo', '<cmd>Open<cr>', { desc = 'E[x]ternal [O]pen (Windows)' })
