-- In-buffer markdown renderer: pretty headings, code blocks, tables,
-- checkboxes, callouts, etc. rendered inline as you edit.
-- Depends on the `markdown` + `markdown_inline` treesitter parsers (already
-- in the ensure_installed list) and nvim-web-devicons for icons.
vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

require('render-markdown').setup {
  -- Render in every mode; anti-conceal (on by default) shows the raw source on
  -- the cursor line (or visual selection) so editing stays unobstructed.
  render_modes = true,
  file_types = { 'markdown' },
  -- Default border = 'hide' conceals the closing ``` line entirely, which also
  -- hides snacks.image's inline mermaid render (attached as virt_lines there).
  code = { border = 'thin' },
}

-- Toggle the rendered view on/off.
vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<cr>', { desc = '[T]oggle [M]arkdown render' })
