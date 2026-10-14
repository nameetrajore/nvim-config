vim.pack.add {
  'https://github.com/stevearc/oil.nvim',
  'https://github.com/refractalize/oil-git-status.nvim',
}

-- Custom "size" column that shows cumulative (recursive) size for directories.
-- Files render instantly from stat; directories are computed asynchronously via
-- `du`, cached, and shown as `…` until the result arrives.
local columns = require 'oil.columns'
local constants = require 'oil.constants'
local FIELD_NAME = constants.FIELD_NAME
local FIELD_TYPE = constants.FIELD_TYPE
local FIELD_META = constants.FIELD_META

local function is_dir(entry)
  local t = entry[FIELD_TYPE]
  if t == 'directory' then
    return true
  elseif t == 'link' then
    local meta = entry[FIELD_META]
    return (meta and meta.link_stat and meta.link_stat.type == 'directory') == true
  end
  return false
end

local function format_size(bytes)
  if bytes >= 1e9 then
    return string.format('%.1fG', bytes / 1e9)
  elseif bytes >= 1e6 then
    return string.format('%.1fM', bytes / 1e6)
  elseif bytes >= 1e3 then
    return string.format('%.1fk', bytes / 1e3)
  else
    return string.format('%d', bytes)
  end
end

local cache = {} -- abs path -> bytes
local inflight = {} -- abs path -> true (queued or running; dedups requests)

-- Debounce re-renders so a burst of finished `du` jobs only redraws once.
local rerender_timer
local function schedule_rerender()
  if rerender_timer then
    rerender_timer:stop()
    rerender_timer:close()
  end
  rerender_timer = vim.defer_fn(function()
    rerender_timer = nil
    require('oil.view').rerender_all_oil_buffers { refetch = false }
  end, 80)
end

-- Cap concurrent `du` subprocesses. Rendering a directory with many subdirs (e.g.
-- .git/objects has ~234) would otherwise spawn one `vim.system` per entry at once;
-- each spawn needs pipe fds, and macOS's default soft maxfiles is only 256, so the
-- burst exhausts the process fd table (EMFILE) and crashes Neovim. A small worker
-- pool keeps the spawn count bounded regardless of how large the directory is.
local MAX_JOBS = 6
local queue = {} -- pending abs paths
local running = 0

local function pump()
  while running < MAX_JOBS and #queue > 0 do
    local path = table.remove(queue, 1)
    running = running + 1
    -- `du -sk` reports cumulative size in 1024-byte blocks.
    vim.system({ 'du', '-sk', path }, { text = true }, function(out)
      running = running - 1
      inflight[path] = nil
      local kb = out.stdout and out.stdout:match '^(%d+)'
      if kb then
        cache[path] = tonumber(kb) * 1024
        schedule_rerender()
      end
      vim.schedule(pump) -- drain the next queued job on the main loop
    end)
  end
end

local function compute_dir_size(path)
  if inflight[path] then
    return
  end
  inflight[path] = true
  table.insert(queue, path)
  pump()
end

columns.register('size', {
  require_stat = true,

  render = function(entry, conf, bufnr)
    if is_dir(entry) then
      local dir = require('oil').get_current_dir(bufnr)
      if not dir then
        return columns.EMPTY
      end
      local path = dir .. entry[FIELD_NAME]
      local bytes = cache[path]
      if bytes then
        return format_size(bytes)
      end
      compute_dir_size(path)
      return { '…', 'OilSize' }
    end

    local meta = entry[FIELD_META]
    local stat = meta and meta.stat
    if not stat then
      return columns.EMPTY
    end
    return format_size(stat.size)
  end,

  get_sort_value = function(entry)
    local meta = entry[FIELD_META]
    local stat = meta and meta.stat
    return (stat and stat.size) or 0
  end,

  parse = function(line, conf)
    return line:match '^(%S+)%s+(.*)$'
  end,
})

-- Collect the paths targeted by a keymap: the visual selection if in visual
-- mode, otherwise just the entry under the cursor. Returns (dir, names, paths).
local function target_entries()
  local oil = require 'oil'
  local dir = oil.get_current_dir()
  if not dir then
    return nil
  end
  local mode = vim.fn.mode()
  local names = {}
  if mode == 'v' or mode == 'V' then
    local s, e = vim.fn.line 'v', vim.fn.line '.'
    if s > e then
      s, e = e, s
    end
    for lnum = s, e do
      local entry = oil.get_entry_on_line(0, lnum)
      if entry then
        table.insert(names, entry.name)
      end
    end
    vim.api.nvim_input '<Esc>'
  else
    local entry = oil.get_cursor_entry()
    if entry then
      names = { entry.name }
    end
  end
  return dir, names
end

-- Run `cmd` (a list) with cwd set to the oil dir, then refresh the buffer.
local function run_in_dir(dir, cmd, done_msg)
  vim.system(cmd, { cwd = dir, text = true }, function(out)
    vim.schedule(function()
      if out.code ~= 0 then
        vim.notify((out.stderr ~= '' and out.stderr) or 'command failed', vim.log.levels.ERROR)
      else
        require('oil.actions').refresh.callback()
        if done_msg then
          vim.notify(done_msg)
        end
      end
    end)
  end)
end

local function zip_entries()
  local dir, names = target_entries()
  if not dir or #names == 0 then
    return
  end
  local default = (names[1] or 'archive') .. '.zip'
  vim.ui.input({ prompt = 'Zip as: ', default = default }, function(out)
    if not out or out == '' then
      return
    end
    local cmd = { 'zip', '-r', out }
    vim.list_extend(cmd, names)
    run_in_dir(dir, cmd, 'Zipped ' .. #names .. ' item(s) -> ' .. out)
  end)
end

local function unzip_entry()
  local oil = require 'oil'
  local dir = oil.get_current_dir()
  local entry = oil.get_cursor_entry()
  if not (dir and entry) then
    return
  end
  if not entry.name:match '%.zip$' then
    vim.notify('Not a .zip: ' .. entry.name, vim.log.levels.WARN)
    return
  end
  run_in_dir(dir, { 'unzip', '-o', entry.name }, 'Unzipped ' .. entry.name)
end

require('oil').setup {
  default_file_explorer = true,
  columns = { 'icon', 'size' },
  -- oil-git-status.nvim draws two status chars (index + working tree) into the
  -- sign column, so it must be at least 2 wide.
  win_options = {
    signcolumn = 'yes:2',
  },
  view_options = {
    show_hidden = true,
  },
  keymaps = {
    ['l'] = 'actions.select',
    ['h'] = 'actions.parent',
    -- Free <C-h>/<C-l> (oil defaults them to split/refresh) so the global
    -- vim-tmux-navigator pane maps work inside oil buffers too.
    ['<C-h>'] = false,
    ['<C-l>'] = false,
    ['<C-r>'] = 'actions.refresh',
    -- gz: zip entry under cursor (or visual selection); prompts for archive name.
    -- gZ: unzip the .zip under cursor into the current dir.
    ['gz'] = { callback = zip_entries, mode = { 'n', 'x' }, desc = 'Zip entry/selection' },
    ['gZ'] = { callback = unzip_entry, desc = 'Unzip entry under cursor' },
  },
}

-- Show git status (staged + unstaged) in oil's sign column.
require('oil-git-status').setup {
  show_ignored = true,
}

vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Oil: open parent directory' })

-- Don't let the global `-` map hijack terminal buffers. After <Esc><Esc> drops
-- you into normal mode in a :term, `-` would otherwise open oil. Keep terminals
-- as terminals only.
vim.api.nvim_create_autocmd('TermOpen', {
  group = vim.api.nvim_create_augroup('oil-no-term-hijack', { clear = true }),
  callback = function(args)
    vim.keymap.set('n', '-', '-', { buffer = args.buf, desc = 'disable oil in terminal' })
  end,
})

-- Inside an oil buffer, scope find_files / live_grep to the directory currently
-- shown in oil (via the per-call `cwd` arg — this does NOT change Vim's real cwd).
-- Same keys as the global pickers; buffer-local override only applies in oil.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'oil',
  group = vim.api.nvim_create_augroup('oil-telescope', { clear = true }),
  callback = function(args)
    local builtin = require 'telescope.builtin'
    local function oil_dir()
      return require('oil').get_current_dir(args.buf)
    end
    vim.keymap.set('n', '<leader>sf', function()
      builtin.find_files { cwd = oil_dir() }
    end, { buffer = args.buf, desc = '[S]earch [F]iles in oil dir' })
    vim.keymap.set('n', '<leader>sg', function()
      builtin.live_grep { cwd = oil_dir() }
    end, { buffer = args.buf, desc = '[S]earch by [G]rep in oil dir' })
    -- Same, but grep *all* files: include hidden dotfiles and gitignored files.
    vim.keymap.set('n', '<leader>sG', function()
      builtin.live_grep {
        cwd = oil_dir(),
        additional_args = { '--hidden', '--no-ignore' },
      }
    end, { buffer = args.buf, desc = '[S]earch by [G]rep (all files) in oil dir' })
  end,
})
