vim.pack.add { 'https://github.com/christoomey/vim-tmux-navigator' }

-- Manage the <C-h/j/k/l> maps ourselves so they supersede the plain
-- window-move maps in init.lua and cross seamlessly into tmux panes.
vim.g.tmux_navigator_no_mappings = 1

vim.keymap.set('n', '<C-h>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Navigate left (vim/tmux)' })
vim.keymap.set('n', '<C-j>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Navigate down (vim/tmux)' })
vim.keymap.set('n', '<C-k>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Navigate up (vim/tmux)' })
vim.keymap.set('n', '<C-l>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Navigate right (vim/tmux)' })
-- <C-\\> intentionally left unbound: reserved for the Claude toggle (see lazygit.lua).
