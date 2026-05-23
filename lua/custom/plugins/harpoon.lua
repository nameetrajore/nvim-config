vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/ThePrimeagen/harpoon',
}

local mark = require 'harpoon.mark'
local ui = require 'harpoon.ui'

vim.keymap.set('n', '<leader>a', function()
  local buftype = vim.bo.buftype
  if buftype == 'terminal' or buftype == 'nofile' then
    vim.notify('Cannot add terminal buffer to harpoon', vim.log.levels.WARN)
    return
  end
  mark.add_file()
end, { desc = 'Harpoon: add file' })
vim.keymap.set('n', '<C-e>', ui.toggle_quick_menu, { desc = 'Harpoon: menu' })

vim.keymap.set('n', '<leader>1', function() ui.nav_file(1) end, { desc = 'Harpoon: file 1' })
vim.keymap.set('n', '<leader>2', function() ui.nav_file(2) end, { desc = 'Harpoon: file 2' })
vim.keymap.set('n', '<leader>3', function() ui.nav_file(3) end, { desc = 'Harpoon: file 3' })
vim.keymap.set('n', '<leader>4', function() ui.nav_file(4) end, { desc = 'Harpoon: file 4' })
