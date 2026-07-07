-- In-buffer markdown renderer: pretty headings, code blocks, tables,
-- checkboxes, callouts, etc. rendered inline as you edit.
-- Depends on the `markdown` + `markdown_inline` treesitter parsers (already
-- in the ensure_installed list) and nvim-web-devicons for icons.
vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

require('render-markdown').setup {
  -- Render in normal/command mode; show raw source while inserting or
  -- visually selecting so editing stays unobstructed.
  render_modes = { 'n', 'c', 't' },
  file_types = { 'markdown' },
}

-- Toggle the rendered view on/off.
vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<cr>', { desc = '[T]oggle [M]arkdown render' })
