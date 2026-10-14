-- Inline image + mermaid rendering (Kitty graphics protocol; works in Ghostty, incl. tmux with allow-passthrough)
-- Requires: `mmdc` (npm i -g @mermaid-js/mermaid-cli) and ImageMagick (`brew install imagemagick`)
vim.pack.add { 'https://github.com/folke/snacks.nvim' }

require('snacks').setup {
  image = {
    enabled = true,
    doc = {
      inline = true, -- render diagrams in place of the code block
      float = true,
    },
  },
}

vim.keymap.set('n', '<leader>ti', function() Snacks.image.hover() end, { desc = '[T]oggle [I]mage hover' })
