vim.pack.add {
  'https://github.com/akinsho/toggleterm.nvim',
}

require('toggleterm').setup()

local Terminal = require('toggleterm.terminal').Terminal
local lazygit = Terminal:new {
  cmd = 'lazygit',
  hidden = true,
  direction = 'float',
  float_opts = { border = 'rounded' },
}

vim.keymap.set('n', '<leader>gg', function() lazygit:toggle() end, { desc = 'Lazygit' })

local persistent = Terminal:new { direction = 'horizontal', size = 15 }
vim.keymap.set({ 'n', 't' }, '<C-_>', function() persistent:toggle() end, { desc = 'Terminal: toggle' })

vim.keymap.set('n', '<leader>ai', '<cmd>term claude<cr>', { desc = 'Claude Code' })
