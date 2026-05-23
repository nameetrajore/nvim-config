vim.pack.add { 'https://github.com/rcarriga/nvim-notify' }

local notify = require 'notify'
notify.setup {
  timeout = 3000,
  on_open = function(win)
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = vim.api.nvim_win_get_buf(win), silent = true })
  end,
}

-- Replace default notify
vim.notify = notify

-- Keymaps
vim.keymap.set('n', '<leader>sn', function()
  require('telescope').extensions.notify.notify()
end, { desc = 'Search notification history' })

vim.keymap.set('n', '<leader>ln', '<cmd>messages<cr>', { desc = 'Neovim messages log' })
vim.keymap.set('n', '<leader>ll', function()
  vim.cmd('edit ' .. vim.fn.stdpath 'log' .. '/log')
end, { desc = 'Neovim log file' })
