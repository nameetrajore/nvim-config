vim.pack.add { 'https://github.com/stevearc/oil.nvim' }

require('oil').setup {
  default_file_explorer = true,
  view_options = {
    show_hidden = true,
  },
  keymaps = {
    ['<C-l>'] = 'actions.select',
    ['<C-h>'] = 'actions.parent',
  },
}

vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Oil: open parent directory' })
