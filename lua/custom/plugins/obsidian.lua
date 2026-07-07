-- Obsidian vault support: follow [[wikilinks]] & #tags, fuzzy-search notes,
-- backlinks, daily notes, and frontmatter management — all from Neovim.
-- Picker auto-detects Telescope; completion auto-detects blink.cmp (both
-- already loaded in init.lua). plenary.nvim is also pulled in by Telescope.
-- In-buffer rendering is left to render-markdown.nvim, so obsidian's own UI
-- concealment is disabled to avoid the two fighting over the same buffer.
vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/obsidian-nvim/obsidian.nvim',
}

-- Candidate vaults as an ORDERED list (name + path relative to $HOME, so
-- nothing is hardcoded to a username or machine). Order matters: when nvim is
-- launched outside any vault, obsidian.nvim falls back to the FIRST registered
-- workspace, so billing-wiki is listed first to be the default. Only vaults
-- that exist on disk are registered, keeping this config portable.
local candidate_vaults = {
  { name = 'billing-wiki', path = '~/code/entomo/billing-wiki' },
  { name = 'personal', path = '~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal' },
  { name = 'icloud', path = '~/Library/Mobile Documents/iCloud~md~obsidian/Documents' },
}

local workspaces = {}
for _, v in ipairs(candidate_vaults) do
  local abs = vim.fn.expand(v.path)
  if vim.fn.isdirectory(abs) == 1 then table.insert(workspaces, { name = v.name, path = abs }) end
end

require('obsidian').setup {
  -- A workspace is matched by cwd; whichever root you open from wins.
  workspaces = workspaces,

  -- render-markdown.nvim owns the pretty rendering; keep obsidian's UI off so
  -- they don't double-conceal headings, links, and checkboxes.
  ui = { enable = false },

  picker = { name = 'telescope.nvim' },
  completion = { blink = true, min_chars = 2 },

  -- Resolve [[links]] to the note's title when it differs from the filename.
  wiki_link_func = 'use_alias_only',
}

-- gf follows the [[wikilink]] / [markdown](link) under the cursor when there
-- is one; otherwise falls through to Neovim's built-in gf (open file under
-- cursor). `obsidian.api.cursor_link()` returns nil when not on a link.
vim.keymap.set('n', 'gf', function()
  local ok, api = pcall(require, 'obsidian.api')
  if ok and api.cursor_link() then
    vim.cmd 'Obsidian follow_link'
  else
    vim.cmd 'normal! gf'
  end
end, { desc = 'Obsidian: follow link under cursor (else builtin gf)' })

-- Note navigation & management (all under <leader>o for [O]bsidian).
vim.keymap.set('n', '<leader>ow', '<cmd>Obsidian workspace<cr>', { desc = '[O]bsidian switch [W]orkspace / vault' })
vim.keymap.set('n', '<leader>oo', '<cmd>Obsidian quick_switch<cr>', { desc = '[O]bsidian [O]pen / switch note' })
vim.keymap.set('n', '<leader>os', '<cmd>Obsidian search<cr>', { desc = '[O]bsidian [S]earch (grep)' })
vim.keymap.set('n', '<leader>ob', '<cmd>Obsidian backlinks<cr>', { desc = '[O]bsidian [B]acklinks' })
vim.keymap.set('n', '<leader>ot', '<cmd>Obsidian tags<cr>', { desc = '[O]bsidian [T]ags' })
vim.keymap.set('n', '<leader>on', '<cmd>Obsidian new<cr>', { desc = '[O]bsidian [N]ew note' })
vim.keymap.set('n', '<leader>ol', '<cmd>Obsidian links<cr>', { desc = '[O]bsidian [L]inks in note' })
vim.keymap.set('v', '<leader>ol', '<cmd>Obsidian link_new<cr>', { desc = '[O]bsidian [L]ink selection to new note' })

-- Claude-in-vault terminal (<leader>oc) disabled.
-- -- Open a Claude Code terminal rooted at the ACTIVE vault dir (so Claude reads
-- -- the vault's CLAUDE.md and operates on the right files). One toggleable
-- -- float per vault dir; reuses toggleterm (already set up in lazygit.lua).
-- local claude_vault_terms = {}
-- vim.keymap.set('n', '<leader>oc', function()
--   local ok, client = pcall(function() return require('obsidian').get_client() end)
--   if not ok or not client then
--     vim.notify('Obsidian: no active vault (open a vault note first)', vim.log.levels.WARN)
--     return
--   end
--   local dir = tostring(client.dir)
--   local term = claude_vault_terms[dir]
--   if not term then
--     term = require('toggleterm.terminal').Terminal:new {
--       cmd = 'claude',
--       dir = dir,
--       hidden = true,
--       direction = 'float',
--       float_opts = { border = 'rounded' },
--       on_open = function(t)
--         -- Land at the prompt, and give the float a buffer-local HIDE key.
--         -- The global <C-\> map shadows the usual <C-\><C-n> escape, so <C-q>
--         -- is the reliable way to tuck Claude away (still running) from inside.
--         vim.cmd 'startinsert'
--         vim.keymap.set({ 't', 'n' }, '<C-q>', function() t:toggle() end, { buffer = t.bufnr, desc = 'Hide Claude (keep running)' })
--       end,
--     }
--     claude_vault_terms[dir] = term
--   end
--   term:toggle()
-- end, { desc = '[O]bsidian: [C]laude in vault dir' })
