-- Workspace jumper: hop straight from inside Neovim into any project you work out
-- of, without dropping to the shell. A "workspace" here is the Personal notes vault
-- (where all work is tracked, inside the iCloud Obsidian vault) plus every repo two
-- levels under ~/code (i.e. ~/code/<org>/<repo>) and this config itself.
--
-- Picking one runs :tcd into it (tab-local cwd, so different tabs can sit in
-- different workspaces) and opens a file finder rooted there — so telescope, oil,
-- and harpoon all operate relative to the chosen project from that point on.
--
-- No plugin to install: telescope is already loaded in init.lua SECTION 4. This
-- file is auto-required by lua/custom/plugins/init.lua's directory scan.

local PERSONAL = vim.env.HOME
  .. '/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal'

local function is_repo(dir)
  return vim.fn.isdirectory(dir .. '/.git') == 1
end

-- Build the candidate list fresh on each invocation so newly-cloned repos show up
-- without editing this file. A workspace under ~/code is a git repo: some orgs sit
-- directly under ~/code (e.g. ~/code/graphify), others are containers whose children
-- are the repos (e.g. ~/code/entomo/wiki), so scan one level down only when the
-- top-level dir isn't itself a repo. Non-repo subdirs (dumps, notes) are skipped.
local function workspace_dirs()
  local dirs = { PERSONAL }
  for _, top in ipairs(vim.fn.glob(vim.env.HOME .. '/code/*', true, true)) do
    if vim.fn.isdirectory(top) == 1 then
      if is_repo(top) then
        table.insert(dirs, top)
      else
        for _, sub in ipairs(vim.fn.glob(top .. '/*', true, true)) do
          if vim.fn.isdirectory(sub) == 1 and is_repo(sub) then
            table.insert(dirs, sub)
          end
        end
      end
    end
  end
  table.insert(dirs, vim.env.HOME .. '/.config/nvim')
  return dirs
end

local function open_workspace(dir)
  vim.cmd.tcd(vim.fn.fnameescape(dir))
  require('telescope.builtin').find_files { cwd = dir }
end

local function pick_workspace()
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'

  pickers
    .new({}, {
      prompt_title = 'Workspaces',
      finder = finders.new_table {
        results = workspace_dirs(),
        entry_maker = function(path)
          -- Show "<repo>  <org>/<repo>" so same-named leaf dirs stay distinguishable.
          local name = vim.fn.fnamemodify(path, ':t')
          local parent = vim.fn.fnamemodify(path, ':h:t')
          return {
            value = path,
            display = string.format('%-20s %s/%s', name, parent, name),
            ordinal = parent .. '/' .. name,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          actions.close(bufnr)
          local sel = action_state.get_selected_entry()
          if sel then
            open_workspace(sel.value)
          end
        end)
        return true
      end,
    })
    :find()
end

vim.keymap.set('n', '<leader>sp', pick_workspace, { desc = '[S]earch [P]roject workspaces' })
