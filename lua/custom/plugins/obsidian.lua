-- Obsidian vault support: follow [[wikilinks]] & #tags, fuzzy-search notes,
-- backlinks, daily notes, and frontmatter management — all from Neovim.
-- Picker uses Telescope (loaded in init.lua); completion comes from the
-- plugin's built-in obsidian-ls LSP server. plenary.nvim is also pulled in by Telescope.
-- In-buffer rendering is left to render-markdown.nvim, so obsidian's own UI
-- concealment is disabled to avoid the two fighting over the same buffer.
vim.pack.add {
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/obsidian-nvim/obsidian.nvim',
}

-- Single vault: the iCloud-synced `Personal` notes. Registered only if present,
-- so this config stays portable to machines without the vault on disk.
local vault = vim.fn.expand '~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal'

if vim.fn.isdirectory(vault) == 1 then
  require('obsidian').setup {
    -- strict = true pins the vault root to this exact path. Without it, obsidian.nvim
    -- walks UP looking for a `.obsidian/` marker and finds `Documents/.obsidian` (the
    -- parent holding alfred/Memex/Personal), scoping the vault to all of Documents —
    -- which is why quick_switch was listing alfred's notes.
    workspaces = { { name = 'Personal', path = vault, strict = true } },

    -- render-markdown.nvim owns the pretty rendering; keep obsidian's UI off so
    -- they don't double-conceal headings, links, and checkboxes.
    ui = { enable = false },

    picker = { name = 'telescope.nvim' },
    -- Completion comes from obsidian.nvim's built-in obsidian-ls LSP server.
    completion = { min_chars = 2 },

    -- Alias-only wiki links: [[Title]] instead of [[file-id|Title]]. Replaces the
    -- removed `wiki_link_func = 'use_alias_only'`. Falls back to the file stem
    -- when a note has no title. Keeps #heading / #^block anchors.
    link = {
      style = function(opts)
        local stem = tostring(opts.path or ''):gsub('%.md$', '')
        local label = opts.label and opts.label ~= '' and opts.label or stem
        local anchor = ''
        if opts.anchor then
          anchor = type(opts.anchor) == 'table' and opts.anchor.anchor or opts.anchor
        elseif opts.block then
          anchor = type(opts.block) == 'table' and ('#' .. opts.block.id) or opts.block
        end
        return string.format('[[%s%s]]', label, anchor)
      end,
    },

    -- Only the new `:Obsidian <subcommand>` form; drops :ObsidianFoo aliases.
    legacy_commands = false,

    -- Vault ships its own template library.
    templates = { folder = 'Templates' },

    -- New notes land in the `in/` inbox, not next to the current file.
    notes_subdir = 'in',
    new_notes_location = 'notes_subdir',

    -- Readable filenames from the title (e.g. `billing-lifecycle.md`) instead of
    -- zettel IDs like `1786002195-OYFI.md`; de-duplicates with a -2, -3 suffix.
    note_id_func = require('obsidian.builtin').title_id,

    -- `:Obsidian today` writes to journal/YYYY-MM-DD.md, matching AGENTS.md.
    daily_notes = { folder = 'journal' },
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
  vim.keymap.set('n', '<leader>oo', '<cmd>Obsidian quick_switch<cr>', { desc = '[O]bsidian [O]pen / switch note' })
  vim.keymap.set('n', '<leader>os', '<cmd>Obsidian search<cr>', { desc = '[O]bsidian [S]earch (grep)' })
  vim.keymap.set('n', '<leader>ob', '<cmd>Obsidian backlinks<cr>', { desc = '[O]bsidian [B]acklinks' })
  vim.keymap.set('n', '<leader>ot', '<cmd>Obsidian tags<cr>', { desc = '[O]bsidian [T]ags' })
  vim.keymap.set('n', '<leader>on', '<cmd>Obsidian new<cr>', { desc = '[O]bsidian [N]ew note' })
  vim.keymap.set('n', '<leader>od', '<cmd>Obsidian today<cr>', { desc = "[O]bsidian to[D]ay's daily note" })
  vim.keymap.set('n', '<leader>oi', '<cmd>Obsidian template<cr>', { desc = '[O]bsidian [I]nsert template' })
  vim.keymap.set('n', '<leader>ol', '<cmd>Obsidian links<cr>', { desc = '[O]bsidian [L]inks in note' })
  vim.keymap.set('v', '<leader>ol', '<cmd>Obsidian link_new<cr>', { desc = '[O]bsidian [L]ink selection to new note' })
end
