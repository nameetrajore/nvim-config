vim.pack.add { 'https://github.com/christoomey/vim-tmux-navigator' }

-- Manage the <C-h/j/k/l> maps ourselves so they supersede the plain
-- window-move maps in init.lua and cross seamlessly into psmux panes.
vim.g.tmux_navigator_no_mappings = 1

vim.keymap.set('n', '<C-h>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Navigate left (vim/psmux)' })
vim.keymap.set('n', '<C-j>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Navigate down (vim/psmux)' })
vim.keymap.set('n', '<C-k>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Navigate up (vim/psmux)' })
vim.keymap.set('n', '<C-l>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Navigate right (vim/psmux)' })
-- <C-\\> intentionally left unbound: reserved for the Claude toggle.

-- psmux reports the deepest child process (roslyn, git…) as pane_current_command, so it
-- can't tell this pane runs nvim. Flag it explicitly via @pane-is-vim for psmux-vim-navigator.
local function pane_is_vim(v)
  if vim.env.TMUX_PANE then vim.system { 'tmux', 'set-option', '-p', '-t', vim.env.TMUX_PANE, '@pane-is-vim', v } end
end
local grp = vim.api.nvim_create_augroup('psmux-pane-is-vim', { clear = true })
vim.api.nvim_create_autocmd({ 'VimEnter', 'VimResume' }, { group = grp, callback = function() pane_is_vim '1' end })
vim.api.nvim_create_autocmd({ 'VimLeavePre', 'VimSuspend' }, { group = grp, callback = function() pane_is_vim '0' end })
