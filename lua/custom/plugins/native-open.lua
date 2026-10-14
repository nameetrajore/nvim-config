-- Open files with the macOS application registered for their type.
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

  vim.system({ 'open', path }, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        vim.notify('Opened: ' .. path)
      else
        vim.notify(('Could not open %s: %s'):format(path, result.stderr), vim.log.levels.ERROR)
      end
    end)
  end)
end

-- :Open opens the current buffer, or a specified path with file completion.
vim.api.nvim_create_user_command('Open', function(opts)
  local path = opts.args ~= '' and opts.args or vim.api.nvim_buf_get_name(0)
  open_native(path, opts.args == '')
end, {
  nargs = '?',
  complete = 'file',
  desc = 'Open a file in its default macOS application',
})

-- <Space>xo opens the current file in Preview, Finder, its default editor, etc.
vim.keymap.set('n', '<leader>xo', '<cmd>Open<cr>', { desc = 'E[x]ternal [O]pen (macOS)' })
