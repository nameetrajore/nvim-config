-- Paste a clipboard image (e.g. a screenshot taken with Ctrl+Cmd+Shift+4) into
-- a markdown note: saves it as a PNG under `assets/` next to the note and
-- inserts the ![](link). snacks.image then renders it inline.
vim.pack.add { 'https://github.com/HakonHarnes/img-clip.nvim' }

require('img-clip').setup {
  default = {
    dir_path = 'assets',
    relative_to_current_file = true, -- assets/ beside the note, not at cwd
    prompt_for_file_name = false, -- timestamped names; rename later if needed
  },
}

vim.keymap.set('n', '<leader>ip', '<cmd>PasteImage<cr>', { desc = '[I]mage [P]aste from clipboard' })
