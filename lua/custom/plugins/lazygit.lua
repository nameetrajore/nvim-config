vim.pack.add {
  'https://github.com/akinsho/toggleterm.nvim',
}

require('toggleterm').setup {
  direction = 'horizontal',
  size = 15,
}

local Terminal = require('toggleterm.terminal').Terminal

-- One lazygit terminal per repo root, opened against the git repo that
-- contains the current file (not nvim's cwd, which may not be a repo).
local lazygit_terms = {}
local function open_lazygit()
  local bufdir
  if vim.bo.filetype == 'oil' then
    bufdir = require('oil').get_current_dir() -- oil buffers are named oil://...
  else
    bufdir = vim.fn.expand('%:p:h')
  end
  if not bufdir or bufdir == '' then bufdir = vim.fn.getcwd() end
  local root = vim.fn.systemlist({ 'git', '-C', bufdir, 'rev-parse', '--show-toplevel' })[1]
  if vim.v.shell_error ~= 0 or not root or root == '' then
    vim.notify('lazygit: not inside a git repository (' .. bufdir .. ')', vim.log.levels.WARN)
    return
  end
  local term = lazygit_terms[root]
  if not term then
    term = Terminal:new {
      cmd = 'lazygit',
      dir = root,
      hidden = true,
      direction = 'float',
      float_opts = { border = 'rounded' },
    }
    lazygit_terms[root] = term
  end
  term:toggle()
end

vim.keymap.set('n', '<leader>gg', open_lazygit, { desc = 'Lazygit (repo of current file)' })

-- Multiple terminals, identified by number. A count prefix picks which one:
--   <C-->        toggle terminal #1
--   2<C-->       toggle terminal #2 (opens it the first time), etc.
-- Counts only work from normal mode; while inside a terminal use <leader>ts
-- (TermSelect) to jump between the open ones.
--
-- Bind both notations: <C--> is what Ghostty (Kitty keyboard protocol) sends
-- for Ctrl+-; <C-_> is the legacy 0x1F byte that older terminals collapse
-- Ctrl+- onto. Mapping both makes the toggle work regardless of protocol.
for _, lhs in ipairs { '<C-->', '<C-_>' } do
  vim.keymap.set('n', lhs, function()
    require('toggleterm').toggle(vim.v.count1)
  end, { desc = 'Terminal: toggle (count = which)' })
  vim.keymap.set('t', lhs, function()
    require('toggleterm').toggle()
  end, { desc = 'Terminal: toggle' })
end

vim.keymap.set({ 'n', 't' }, '<leader>ts', '<cmd>TermSelect<cr>', { desc = 'Terminal: select open' })

-- Claude toggle disabled.
-- local claude_width = 0.4
-- local function claude_cols() return math.floor(vim.o.columns * claude_width) end
-- local claude = Terminal:new {
--   cmd = 'claude',
--   hidden = true,
--   direction = 'vertical',
--   size = claude_cols,
--   on_open = function(term)
--     vim.cmd('wincmd L') -- anchor to far-right, full height regardless of focus
--     vim.cmd('vertical resize ' .. claude_cols())
--     vim.schedule(function() vim.cmd('startinsert') end) -- land in terminal mode at the prompt
--   end,
-- }
-- vim.keymap.set({ 'n', 't' }, '<C-\\>', function() claude:toggle() end, { desc = 'Claude: toggle' })
