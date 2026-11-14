-- C-h/j/k/l across nvim splits and psmux panes (vim-tmux-navigator equivalent, no plugin).
-- vim-tmux-navigator shells out with shellcmdflag forced to '-c', which cmd.exe ignores, so it
-- never reaches psmux on Windows. Here: move within nvim; at the edge, ask psmux to move.
-- <C-\\> intentionally left unbound: reserved for the Claude toggle.
local dirs = { h = 'L', j = 'D', k = 'U', l = 'R' }
local function navigate(d)
  local win = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(d)
  if vim.api.nvim_get_current_win() == win and vim.env.TMUX_PANE then
    vim.system { 'tmux', 'select-pane', '-t', vim.env.TMUX_PANE, '-' .. dirs[d] }
  end
end
for d in pairs(dirs) do
  vim.keymap.set('n', '<C-' .. d .. '>', function() navigate(d) end, { desc = 'Navigate ' .. d .. ' (vim/psmux)' })
end

-- psmux reports the deepest child process (roslyn, git…) as pane_current_command, so it
-- can't tell this pane runs nvim. Flag it via @pane-is-vim for psmux-vim-navigator.
local function pane_is_vim(v)
  if vim.env.TMUX_PANE then vim.system { 'tmux', 'set-option', '-p', '-t', vim.env.TMUX_PANE, '@pane-is-vim', v } end
end
local grp = vim.api.nvim_create_augroup('psmux-pane-is-vim', { clear = true })
vim.api.nvim_create_autocmd({ 'VimEnter', 'VimResume' }, { group = grp, callback = function() pane_is_vim '1' end })
vim.api.nvim_create_autocmd({ 'VimLeavePre', 'VimSuspend' }, { group = grp, callback = function() pane_is_vim '0' end })
