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
--   i            commit info: full message, author, date (panel, or a read-only diff side)
--   <Tab>        switch focus between the panel and the diff
--   q  or  :q    close the whole Diffview tab
--   q / <Esc>    in a popup (help, commit info) or the g! options split: close just that;
--                :q there also closes only that sub-panel
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
local function is_float(win) return vim.api.nvim_win_get_config(win or 0).relative ~= '' end
local OPTIONS_PANEL = 'DiffviewFHOptionPanel' -- the g! options split under the history panel
-- Popups (help, commit info) and the options split: opened on top of Diffview and closed again.
local function in_subpanel() return is_float() or vim.api.nvim_buf_get_name(0):match(OPTIONS_PANEL) ~= nil end

-- `:q` inside a Diffview tab closes the whole view; inside a popup/options split, just that.
vim.keymap.set('ca', 'q', function()
  if vim.fn.getcmdtype() == ':' and vim.fn.getcmdline() == 'q' and in_diffview() and not in_subpanel() then
    return 'DiffviewClose'
  end
  return 'q'
end, { expr = true, desc = ':q closes Diffview, or just the popup when in one' })

local grp = vim.api.nvim_create_augroup('custom-diffview', { clear = true })

-- Windows: swap file names for deep `diffview://` paths exceed MAX_PATH (260), so naming the
-- buffer fails with E303 ("Failed to create diff buffer"). Buffers named after creation
-- (diffview's, scratch) skip the swap file; files opened from disk keep theirs.
vim.api.nvim_create_autocmd('BufFilePre', {
  group = grp,
  callback = function(ev)
    if vim.api.nvim_buf_get_name(ev.buf) == '' then vim.bo[ev.buf].swapfile = false end
  end,
})

-- Commit-info float has no keys of its own: give it q / <Esc>. diffview sets filetype=git
-- before naming the buffer, so check the name once it's built.
vim.api.nvim_create_autocmd('FileType', {
  group = grp,
  pattern = 'git',
  callback = function(ev)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(ev.buf) then return end
      if not vim.api.nvim_buf_get_name(ev.buf):match '^diffview://.*/commit_log' then return end
      for _, key in ipairs { 'q', '<Esc>' } do
        vim.keymap.set('n', key, '<cmd>close<cr>', { buffer = ev.buf, nowait = true, desc = 'Close commit info' })
      end
    end)
  end,
})

vim.api.nvim_create_autocmd('BufWinEnter', {
  group = grp,
  callback = function(ev)
    local name = vim.api.nvim_buf_get_name(ev.buf)
    -- g! options split: <Esc> closes it like q (matches help and commit info).
    if name:match(OPTIONS_PANEL) then
      vim.keymap.set('n', '<Esc>', actions.close, { buffer = ev.buf, nowait = true, desc = 'Close options' })
      return
    end
    -- `i` = commit info on read-only revision sides; the editable working-tree side keeps insert.
    if name:match '^diffview://' and not vim.bo[ev.buf].modifiable and not name:match '/panels/' and not name:match '/commit_log' then
      vim.keymap.set('n', 'i', actions.open_commit_log, { buffer = ev.buf, nowait = true, desc = 'Commit info' })
    end
  end,
})

vim.keymap.set('n', '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', { desc = 'git [h]istory of this file' })
vim.keymap.set('n', '<leader>gc', '<cmd>DiffviewFileHistory<cr>', { desc = 'git [c]ommits (whole repo)' })
vim.keymap.set('n', '<leader>gl', '<cmd>.DiffviewFileHistory<cr>', { desc = 'git history of current [l]ine' })
vim.keymap.set('v', '<leader>gl', ":'<,'>DiffviewFileHistory<cr>", { desc = 'git history of selected [l]ines' })
vim.keymap.set('n', '<leader>gv', function()
  vim.cmd(in_diffview() and 'DiffviewClose' or 'DiffviewOpen')
end, { desc = 'git diff[v]iew: toggle (uncommitted changes)' })
