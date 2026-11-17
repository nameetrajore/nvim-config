# Repository guide for coding agents

## Project and layout

Personal Neovim configuration derived from kickstart.nvim, installed at
`~/.config/nvim`. Targets recent stable/nightly Neovim with `vim.pack` support.

- `init.lua`: base configuration, organized into numbered, scoped sections:
  foundation, plugin manager/build hooks, UI, search, LSP, formatting,
  completion/snippets, Treesitter, and optional examples.
- `lua/custom/plugins/*.lua`: personal additions. Prefer these files for new
  customizations to minimize conflicts with upstream kickstart changes.
- `lua/custom/plugins/init.lua` automatically requires every sibling Lua file
  except itself. No manual import list is needed.

## Plugin management

Use **`vim.pack`**, not lazy.nvim:

- Install with `vim.pack.add { 'https://github.com/owner/repo' }`.
- Configure explicitly with `require('plugin').setup { ... }` afterward.
- Custom plugin files execute imperatively; do not return lazy.nvim spec tables
  or use lazy-only fields such as `config`, `event`, or `dependencies`.
- The `gh` URL helper is local to `init.lua`; use full URLs in custom files.
- Put build steps in the existing `PackChanged` autocommand in `init.lua`
  section 2, keyed by plugin name.
- Update plugins with `:lua vim.pack.update()`. `lazy-lock.json` is obsolete.

## Conventions

- Both leader and localleader are Space. Check existing mappings before adding
  shortcuts and provide descriptive `desc` values.
- Respect `vim.g.have_nerd_font` when adding icons.
- Follow surrounding Lua style: two-space indentation and single-quoted strings.
- Add LSP servers to the `servers` table in `init.lua` section 5; its keys feed
  mason-tool-installer automatically.
- Configure formatters in section 6's `formatters_by_ft` table.

## Workspace and worktree navigation

`lua/custom/plugins/workspaces.lua` implements navigation using the existing
Telescope installation; no additional plugin is required.

- `<leader>sp`: project workspaces plus linked Git worktrees. Scans repositories
  directly under `~/code` and one organization level deeper, includes the
  Personal Obsidian vault if present and this configuration, and discovers
  worktrees belonging to the current repository as well.
- `<leader>sW`: worktrees belonging to the repository containing the current cwd.
- Selection changes the **tab-local** cwd with `:tcd`, then opens file search.
- Entries show branch/detached status, paths, and `*` for the current cwd.
- Refresh discovery each invocation. Linked worktrees have a `.git` **file**;
  do not restrict detection to `.git` directories.
- Use `git worktree list --porcelain -z` via an argument-list subprocess for
  worktree discovery; preserve paths containing spaces or special characters.
- Deduplicate paths, skip missing worktrees and bare entries, and retain support
  for linked worktrees located outside the scanned workspace roots.

## Validation

There is no dedicated test/build/lint suite. For changes:

1. Run `git diff --check`.
2. Check Lua syntax with Neovim, for example:
   `nvim --headless -u NONE '+lua assert(loadfile("lua/custom/plugins/workspaces.lua"))' +qa`.
3. Exercise changed behavior in Neovim; a syntax check alone does not verify
   plugin initialization or interactive mappings.
4. For worktree changes, test a temporary Git repository with regular and
   detached worktrees, a path containing spaces, selection/cwd changes, and
   deduplication. Headless tests may stub Telescope to inspect picker entries.

Avoid running a full config startup merely to check syntax: it can install or
update plugins and trigger build hooks. Report which checks were actually run.
