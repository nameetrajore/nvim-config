-- diffview.nvim: browse commits as a tab with a file panel + side-by-side diff.
--
-- Entry points:
--   <leader>gh   history of this file
--   <leader>gc   history of the whole repo (every commit, every file it touched)
--   <leader>gl   history of the current line / visual selection
--   <leader>gv   toggle: uncommitted changes
--
-- Inside Diffview — same keys in the diff and in the panel, no window-jump keys
-- needed (<C-j> etc. collide with Rex):
--   L / H        next / previous file (in history: steps through commits)
--   J / K        next / previous change in the diff (centred)
--   j / k, <CR>  (panel) move, then open the entry under the cursor
--   i            (panel) commit info: full message, author, date
--   <Tab>        switch focus between the panel and the diff
--   q  or  :q    close the whole Diffview tab
--   g?           list every keymap in the current panel
--
--   :DiffviewOpen <rev>    diff working tree against <rev> (e.g. HEAD~3, main)
--   :DiffviewOpen <sha>^!  just the changes in one commit
vim.pack.add { 'https://github.com/sindrets/diffview.nvim' }

local actions = require 'diffview.actions'

-- Keys shared by every Diffview context.
local common = {
  { 'n', 'q', '<cmd>DiffviewClose<cr>', { desc = 'Close Diffview' } },
  { 'n', 'L', actions.select_next_entry, { desc = 'Next file' } },
  { 'n', 'H', actions.select_prev_entry, { desc = 'Previous file' } },
}

-- Panels: i shows commit info, <Tab> jumps back to the diff.
local panel = vim.list_extend({
  { 'n', 'i', actions.open_commit_log, { desc = 'Commit info' } },
  { 'n', '<tab>', '<cmd>wincmd p<cr>', { desc = 'Focus the diff' } },
  { 'n', '<s-tab>', '<cmd>wincmd p<cr>', { desc = 'Focus the diff' } },
}, vim.deepcopy(common))

require('diffview').setup {
  keymaps = {
    view = vim.list_extend({
      { 'n', 'J', '<cmd>normal! ]czz<cr>', { desc = 'Next change' } },
      { 'n', 'K', '<cmd>normal! [czz<cr>', { desc = 'Previous change' } },
      { 'n', '<tab>', actions.focus_files, { desc = 'Focus the panel' } },
      { 'n', '<s-tab>', actions.focus_files, { desc = 'Focus the panel' } },
    }, vim.deepcopy(common)),
    file_panel = panel,
    file_history_panel = vim.deepcopy(panel),
  },
}

local function in_diffview()
  return require('diffview.lib').get_current_view() ~= nil
end

-- `:q` inside a Diffview tab closes the whole view instead of one split.
vim.keymap.set('ca', 'q', function()
  if vim.fn.getcmdtype() == ':' and vim.fn.getcmdline() == 'q' and in_diffview() then
    return 'DiffviewClose'
  end
  return 'q'
end, { expr = true, desc = ':q closes Diffview when inside one' })

vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', { desc = 'git [h]istory of this file' })
vim.keymap.set('n', '<leader>gc', '<cmd>DiffviewFileHistory<cr>', { desc = 'git [c]ommits (whole repo)' })
vim.keymap.set('n', '<leader>gl', '<cmd>.DiffviewFileHistory<cr>', { desc = 'git history of current [l]ine' })
vim.keymap.set('v', '<leader>gl', ":'<,'>DiffviewFileHistory<cr>", { desc = 'git history of selected [l]ines' })
vim.keymap.set('n', '<leader>gv', function()
  vim.cmd(in_diffview() and 'DiffviewClose' or 'DiffviewOpen')
end, { desc = 'git diff[v]iew: toggle (uncommitted changes)' })
