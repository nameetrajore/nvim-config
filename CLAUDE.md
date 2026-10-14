# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal Neovim config derived from [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim). Config lives at `~/.config/nvim`. Targets latest stable/nightly Neovim.

## Plugin manager: `vim.pack`, not lazy.nvim

This config has migrated off lazy.nvim to **`vim.pack`**, Neovim's built-in package manager. This is the single most important thing to know before editing:

- Install a plugin with `vim.pack.add { 'https://github.com/owner/repo' }` (or `vim.pack.add { gh 'owner/repo' }` — `gh` is a helper defined in `init.lua` that prefixes the GitHub URL).
- Plugins must still be started explicitly with their `require('name').setup {}` after `vim.pack.add`. Installing alone does nothing.
- Build steps (make, TSUpdate, etc.) run via a single `PackChanged` autocommand in `init.lua` (SECTION 2). Add new build logic there, keyed on plugin `name`.
- Do **not** write lazy.nvim-style spec tables (`{ 'owner/repo', config = ..., event = ... }`). They will not work.
- Update plugins with `:lua vim.pack.update()`. `lazy-lock.json` is a stale leftover from the lazy era.

## Two-layer structure

**`init.lua`** — the kickstart base, ~1100 lines, organized into numbered `SECTION` blocks wrapped in `do ... end` scopes:
1. FOUNDATION (options, `<space>` leader, keymaps, autocommands)
2. PLUGIN MANAGER INTRO (`vim.pack` setup + `PackChanged` build autocommand)
3. UI / CORE UX (guess-indent, gitsigns, which-key, tokyonight, mini.*)
4. SEARCH & NAVIGATION (telescope + keymaps)
5. LSP (mason, server table at the `local servers = {}` around line 809, on-attach keymaps)
6. FORMATTING (conform, `formatters_by_ft`)
7. AUTOCOMPLETE & SNIPPETS (blink.cmp, luasnip)
8. TREESITTER
9. OPTIONAL EXAMPLES — ends by calling `require 'custom.plugins'`

**`lua/custom/plugins/*.lua`** — personal additions, kept out of `init.lua` to avoid merge conflicts when pulling kickstart upstream. Current files: oil, flash, harpoon, notify, undotree, vim-tmux-navigator, obsidian, render-markdown, live-preview, snacks-image, native-open, workspaces.

## How custom plugins load

`lua/custom/plugins/init.lua` **scans the directory and `require`s every `*.lua` file** (except `init.lua`) at startup. There is no manual import list — dropping a new `foo.lua` into that directory is all that's needed to load it.

Because each custom file is `require`'d directly (not returned as a lazy spec), a custom plugin file is **imperative top-to-bottom**: it calls `vim.pack.add {...}`, then `require('plugin').setup {}`, then defines keymaps inline. Follow that pattern (see `flash.lua` for a minimal example, `oil.lua` for a complex one). Do not `return` a table from these files.

## Adding an LSP server

Add an entry to the `servers` table in `init.lua` SECTION 5. Its keys are auto-fed to mason-tool-installer via `vim.tbl_keys(servers)`, so no separate install step is needed.

## Conventions

- Leader and localleader are both `<space>`.
- `vim.g.have_nerd_font` gates icon usage; currently `false`.
- There is no test/build/lint suite — this is editor config. "Testing" a change means opening `nvim` and exercising it, or `:source %` / restarting.
