-- Workspace and Git worktree navigation. Selecting an entry changes the tab-local
-- cwd and opens Telescope's file finder. No additional plugins required.

local PERSONAL = vim.env.HOME
  .. '/Library/Mobile Documents/iCloud~md~obsidian/Documents/Personal'

local function is_repo(dir)
  -- Linked worktrees have a .git file, not a directory.
  return vim.fn.isdirectory(dir .. '/.git') == 1 or vim.fn.filereadable(dir .. '/.git') == 1
end

local function worktrees(dir)
  if vim.fn.executable 'git' ~= 1 then
    return {}
  end
  local result = vim.system({ 'git', '-C', dir, 'worktree', 'list', '--porcelain', '-z' }):wait()
  if result.code ~= 0 then
    return {}
  end

  local entries, entry = {}, nil
  -- NUL-delimited fields preserve spaces and other special characters in paths.
  for _, field in ipairs(vim.split(result.stdout, '\0', { plain = true })) do
    if vim.startswith(field, 'worktree ') then
      entry = { path = field:sub(10) }
      table.insert(entries, entry)
    elseif entry then
      if vim.startswith(field, 'branch ') then
        entry.branch = field:sub(8):gsub('^refs/heads/', '')
      elseif field == 'detached' then
        entry.branch = 'detached'
      elseif field == 'bare' then
        entry.bare = true
      end
    end
  end
  return vim.tbl_filter(function(item)
    return not item.bare and vim.fn.isdirectory(item.path) == 1
  end, entries)
end

-- Scan repos directly under ~/code or one org level deeper, then ask Git for
-- their worktrees (including those stored outside ~/code). Refresh on each use.
local function workspace_entries()
  local entries, seen = {}, {}
  local function add(entry)
    local key = vim.uv.fs_realpath(entry.path) or entry.path
    if not seen[key] and vim.fn.isdirectory(entry.path) == 1 then
      seen[key] = true
      table.insert(entries, entry)
    end
  end
  local function add_repo(dir)
    for _, entry in ipairs(worktrees(dir)) do
      add(entry)
    end
    add { path = dir }
  end

  add { path = PERSONAL }
  for _, top in ipairs(vim.fn.glob(vim.env.HOME .. '/code/*', true, true)) do
    if vim.fn.isdirectory(top) == 1 then
      if is_repo(top) then
        add_repo(top)
      else
        for _, sub in ipairs(vim.fn.glob(top .. '/*', true, true)) do
          if vim.fn.isdirectory(sub) == 1 and is_repo(sub) then
            add_repo(sub)
          end
        end
      end
    end
  end
  add_repo(vim.env.HOME .. '/.config/nvim')
  -- Also include the current repo, even when it lives outside the usual roots.
  for _, entry in ipairs(worktrees(vim.fn.getcwd())) do
    add(entry)
  end
  return entries
end

local function pick_entries(title, entries)
  if #entries == 0 then
    vim.notify('No Git worktrees found for the current directory.', vim.log.levels.INFO)
    return
  end
  local pickers = require 'telescope.pickers'
  local finders = require 'telescope.finders'
  local conf = require('telescope.config').values
  local actions = require 'telescope.actions'
  local action_state = require 'telescope.actions.state'
  local cwd = vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()

  pickers
    .new({}, {
      prompt_title = title,
      finder = finders.new_table {
        results = entries,
        entry_maker = function(entry)
          local name = vim.fn.fnamemodify(entry.path, ':t')
          local path = vim.fn.fnamemodify(entry.path, ':~')
          local branch = entry.branch and (' [' .. entry.branch .. ']') or ''
          local current = (vim.uv.fs_realpath(entry.path) or entry.path) == cwd and '* ' or '  '
          return {
            value = entry.path,
            display = string.format('%s%-20s%s  %s', current, name, branch, path),
            ordinal = name .. ' ' .. (entry.branch or '') .. ' ' .. path,
          }
        end,
      },
      sorter = conf.generic_sorter {},
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local sel = action_state.get_selected_entry()
          actions.close(bufnr)
          if sel then
            vim.cmd.tcd(vim.fn.fnameescape(sel.value))
            require('telescope.builtin').find_files { cwd = sel.value }
          end
        end)
        return true
      end,
    })
    :find()
end

vim.keymap.set('n', '<leader>sp', function()
  pick_entries('Workspaces & worktrees', workspace_entries())
end, { desc = '[S]earch [P]roject workspaces' })

vim.keymap.set('n', '<leader>sW', function()
  pick_entries('Git worktrees', worktrees(vim.fn.getcwd()))
end, { desc = '[S]earch Git [W]orktrees' })
