-- Markdown list editing via bullets.vim: <CR> / o continue the current bullet,
-- numbered item or checkbox (an empty item ends the list), numbered lists
-- renumber themselves, and items indent/outdent with their children.
--
--   insert  <CR>          new item (on an empty item: end the list)
--   insert  <C-t> / <C-d> indent / outdent item
--   normal  o             new item below
--   (>> / << and visual > / < live in markdown-structure.lua: they also
--    change heading levels there, and renumber lists afterwards.)
--   normal  <leader>c     toggle checkbox  [ ] <-> [x]
--   normal  gN            renumber list             (visual too)

-- Globals must be set before the plugin loads (vim.pack.add sources it).
vim.g.bullets_enabled_file_types = { 'markdown', 'text', 'gitcommit' }
vim.g.bullets_checkbox_markers = ' x' -- plain [ ] / [x], as Obsidian writes them
vim.g.bullets_outline_levels = {} -- indenting keeps the item's own style (1. stays 1., - stays -)
-- bullets.vim's renumbering treats a list as running until the next blank
-- line, so it continues numbers across a heading. markdown-structure.lua
-- renumbers markdown lists instead; it ends a list at any heading or text.
vim.g.bullets_renumber_on_change = 0
vim.g.bullets_set_mappings = 0 -- defaults put the checkbox on <leader>x, which clashes
vim.g.bullets_custom_mappings = {
  { 'imap', '<cr>', '<Plug>(bullets-newline)' },
  { 'inoremap', '<C-cr>', '<cr>' }, -- plain newline, no bullet
  { 'nmap', 'o', '<Plug>(bullets-newline)' },
  { 'imap', '<C-t>', '<Plug>(bullets-demote)' },
  { 'imap', '<C-d>', '<Plug>(bullets-promote)' },
  { 'nmap', '<leader>c', '<Plug>(bullets-toggle-checkbox)' },
  { 'nmap', 'gN', '<Plug>(bullets-renumber)' },
  { 'vmap', 'gN', '<Plug>(bullets-renumber)' },
}

vim.pack.add { 'https://github.com/bullets-vim/bullets.vim' }
