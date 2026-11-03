-- Org-mode-style structure editing for markdown notes. Vim-style keys (no Alt),
-- buffer-local to markdown. Works on headings and list items; lists come from
-- bullets.vim (lists.lua), whose <CR>/o, <leader>c and gN stay as they are.
--
--   Org            Here            Action
--   M-→ / M-←      >> / <<         demote / promote heading (# count), else indent / outdent   (visual: > / <)
--   M-S-→ / M-S-←  >s / <s         same, with the whole subtree (section / child items)
--   M-↓ / M-↑      <leader>j / k   move heading section or item (with children) past its sibling
--   M-RET          <leader><CR>    new sibling heading / item below, in insert mode
--   C-c -          <leader>-       cycle list type: plain → - → 1. → - [ ] → plain   (visual too;
--                                  on an empty line: start a `- ` bullet)
--   C-c *          <leader>#       toggle line ↔ heading (level of the heading above)
--                  <leader>m1..m6  set heading level · <leader>m0 remove heading
--   C-c C-n/p      ]] / [[         next / previous heading (skips code blocks)
--   C-c C-u        [u              up to parent heading
--   TAB / S-TAB    za / <S-Tab>    fold section / cycle: overview → one level → all open
--
-- Numbered lists are renumbered after every change (and on gN). Normal-mode
-- edits repeat with `.`. Heading levels live under <leader>m because harpoon
-- owns <leader>1-4.

local api = vim.api

-- [[ Parsing ]] ---------------------------------------------------------------

-- Lines inside fenced code blocks or YAML frontmatter: never headings or items.
local function code_map(ls)
  local code, fence = {}, nil
  local i = 1
  if ls[1] == '---' then
    code[1] = true
    for j = 2, #ls do
      code[j] = true
      if ls[j] == '---' or ls[j] == '...' then
        i = j + 1
        break
      end
    end
  end
  for j = i, #ls do
    local f = ls[j]:match '^%s*(```+)' or ls[j]:match '^%s*(~~~+)'
    if fence then
      code[j] = true
      if f and f:sub(1, 1) == fence:sub(1, 1) and #f >= #fence and ls[j]:match '^%s*[`~]+%s*$' then fence = nil end
    elseif f then
      fence, code[j] = f, true
    end
  end
  return code
end

local function ctx()
  local ls = api.nvim_buf_get_lines(0, 0, -1, false)
  return { ls = ls, code = code_map(ls) }
end

local function heading_at(c, i)
  if c.code[i] or not c.ls[i] then return nil end
  local h = c.ls[i]:match '^(#+)%s' or c.ls[i]:match '^(#+)$'
  return h and #h <= 6 and #h or nil
end

local function parse_item(l)
  local ind, rest = l:match '^(%s*)(.*)$'
  local b, box, text = rest:match '^([-*+]) %[(.)%] ?(.*)$'
  if b then return { indent = #ind, kind = 'task', bullet = b, box = box, text = text } end
  b, text = rest:match '^([-*+]) (.*)$'
  if b then return { indent = #ind, kind = 'bullet', bullet = b, text = text } end
  local n, d
  n, d, text = rest:match '^(%d+)([.)]) (.*)$'
  if n then return { indent = #ind, kind = 'number', num = tonumber(n), delim = d, text = text } end
end

local function item_at(c, i)
  if c.code[i] or not c.ls[i] then return nil end
  return parse_item(c.ls[i])
end

local function fmt(it)
  local pre = (' '):rep(it.indent)
  if it.kind == 'task' then return pre .. (it.bullet or '-') .. ' [' .. (it.box or ' ') .. '] ' .. it.text end
  if it.kind == 'number' then return pre .. (it.num or 1) .. (it.delim or '.') .. ' ' .. it.text end
  return pre .. (it.bullet or '-') .. ' ' .. it.text
end

-- Last line of the section a heading of level `lvl` at line i owns.
local function section_end(c, i, lvl)
  for j = i + 1, #c.ls do
    local h = heading_at(c, j)
    if h and h <= lvl then return j - 1 end
  end
  return #c.ls
end

-- Last line of a list item plus its children / continuation lines.
local function item_end(c, i)
  local ind, e = item_at(c, i).indent, i
  for j = i + 1, #c.ls do
    local l = c.ls[j]
    if l:match '^%s*$' or #l:match '^%s*' <= ind then break end
    e = j
  end
  return e
end

-- [[ Editing helpers ]] -------------------------------------------------------

local function cur() return api.nvim_win_get_cursor(0)[1] end
local function set_line(i, s) api.nvim_buf_set_lines(0, i - 1, i, false, { s }) end
-- Line text without its heading `#`s or list marker. Only a real heading
-- prefix (`# `) is stripped, so an Obsidian `#tag` at line start survives.
local function strip_marker(c, i)
  if heading_at(c, i) then return (c.ls[i]:gsub('^#+%s*', '')) end
  local it = item_at(c, i)
  if it then return it.text end
  return (c.ls[i]:gsub('^%s*', ''))
end
local function set_heading(c, i, lvl)
  if lvl == 0 and not heading_at(c, i) then return end -- "remove heading" leaves lists alone
  local body = strip_marker(c, i)
  set_line(i, lvl == 0 and body or ('#'):rep(lvl) .. ' ' .. body)
end

-- Make an action dot-repeatable: run it through 'operatorfunc' with `g@_`.
-- The count is captured once, so `.` repeats with the same count.
_G.__md_structure_op = function() end
local function repeatable(fn)
  return function()
    local count = vim.v.count1
    _G.__md_structure_op = function() fn(count) end
    vim.go.operatorfunc = 'v:lua.__md_structure_op'
    return 'g@_'
  end
end

local function set_jump()
  if api.nvim_get_mode().mode == 'n' then vim.cmd "normal! m'" end
end

-- Renumber every ordered list in the buffer: consecutive items at one indent
-- count up from 1. Non-indented text ends a list.
-- `join` merges the edits into the previous undo step (used by the automatic
-- renumber after each change, so one `u` undoes the change and its renumber).
local function renumber(join)
  local c, counters = ctx(), {}
  local joined = not join
  local function drop(from)
    for k in pairs(counters) do
      if k >= from then counters[k] = nil end
    end
  end
  for i, l in ipairs(c.ls) do
    if not c.code[i] and not l:match '^%s*$' then
      local it = parse_item(l)
      if it then
        drop(it.indent + 1)
        if it.kind == 'number' then
          local n = (counters[it.indent] or 0) + 1
          counters[it.indent] = n
          if n ~= it.num then
            if not joined then joined = pcall(vim.cmd, 'undojoin') or true end
            it.num = n
            set_line(i, fmt(it))
          end
        else
          counters[it.indent] = nil
        end
      else
        drop(#l:match '^%s*')
      end
    end
  end
end

local function visual_range()
  vim.cmd('normal! ' .. vim.keycode '<Esc>')
  return vim.fn.line "'<", vim.fn.line "'>"
end

-- [[ Actions ]] ---------------------------------------------------------------

-- One rule for every line in [s, e]: a heading changes level by `delta`
-- (clamped to 1–6); any other line shifts by `delta` shiftwidths.
local function shift_lines(s, e, delta)
  local c = ctx()
  for j = s, e do
    local h = heading_at(c, j)
    if h then
      local n = math.min(6, math.max(1, h + delta))
      if n ~= h then set_heading(c, j, n) end
    elseif not c.ls[j]:match '^%s*$' then
      vim.cmd(('silent %d%s'):format(j, (delta > 0 and '>' or '<'):rep(math.abs(delta))))
    end
  end
  renumber()
end

-- >> / << : current line (count = number of lines, as in builtin >>).
local function shift(delta)
  return function(count)
    local i = cur()
    shift_lines(i, math.min(i + count - 1, api.nvim_buf_line_count(0)), delta)
  end
end

local function shift_visual(delta)
  local count = vim.v.count1
  local s, e = visual_range()
  shift_lines(s, e, delta * count)
end

-- >s / <s : heading with its whole section, or item with its children.
local function shift_tree(delta)
  local c, i = ctx(), cur()
  local h = heading_at(c, i)
  if h then
    local e = section_end(c, i, h)
    for j = i, e do
      local hj = heading_at(c, j)
      if hj and (hj + delta < 1 or hj + delta > 6) then return vim.notify('Heading level out of range (1–6)', vim.log.levels.WARN) end
    end
    for j = i, e do
      local hj = heading_at(c, j)
      if hj then set_heading(c, j, hj + delta) end
    end
    return
  end
  local it = item_at(c, i)
  if not it or (delta < 0 and it.indent == 0) then return end
  vim.cmd(('silent %d,%d%s'):format(i, item_end(c, i), delta > 0 and '>' or '<'))
  renumber()
end

-- Block under the cursor: a heading's section or an item with its children.
-- Returns start, end, and a predicate for "line j starts a sibling block".
local function block_at(c, i)
  local h = heading_at(c, i)
  if h then
    return i, section_end(c, i, h), function(j) return heading_at(c, j) == h end, function(j)
      local hj = heading_at(c, j)
      return hj and hj < h
    end
  end
  local it = item_at(c, i)
  if it then
    return i, item_end(c, i), function(j)
      local o = item_at(c, j) -- same indent, and both ordered or both unordered
      return o and o.indent == it.indent and (o.kind == 'number') == (it.kind == 'number')
    end, function(j)
      local l = c.ls[j]
      return l:match '^%s*$' or #l:match '^%s*' < it.indent
    end
  end
end

-- Swap adjacent ranges [s1,e1] and [s2,e2] (s2 == e1 + 1). A trailing blank
-- line stays at the boundary so sections don't fuse together.
local function swap(c, s1, e1, s2, e2)
  local a = vim.list_slice(c.ls, s1, e1)
  local b = vim.list_slice(c.ls, s2, e2)
  local blank = function(t) return t[#t] and t[#t]:match '^%s*$' end
  if blank(a) and not blank(b) then
    table.remove(a)
    table.insert(b, '')
  end
  api.nvim_buf_set_lines(0, s1 - 1, e2, false, vim.list_extend(vim.list_extend({}, b), a))
  return #b
end

local function move(dir)
  local c, i = ctx(), cur()
  local col = api.nvim_win_get_cursor(0)[2]
  local s, e, sibling, stop = block_at(c, i)
  if not s then
    pcall(vim.cmd, dir > 0 and 'silent move .+1' or 'silent move .-2')
    return
  end
  if dir > 0 then
    local ns = e + 1
    if not sibling(ns) then return end
    local _, ne = block_at(c, ns)
    local nb = swap(c, s, e, ns, ne)
    api.nvim_win_set_cursor(0, { s + nb, col })
  else
    for j = s - 1, 1, -1 do
      if sibling(j) then
        local _, pe = block_at(c, j)
        if pe == s - 1 then
          swap(c, j, pe, s, e)
          api.nvim_win_set_cursor(0, { j, col })
        end
        break
      end
      if stop(j) then break end
    end
  end
  renumber()
end

-- <leader><CR> : new sibling below, in insert mode.
local function new_sibling()
  local c, i = ctx(), cur()
  local h = heading_at(c, i)
  if h then
    local last = section_end(c, i, h)
    while last > i and c.ls[last]:match '^%s*$' do
      last = last - 1
    end
    local head = ('#'):rep(h) .. ' '
    local ins = { '', head }
    if c.ls[last + 1] and not c.ls[last + 1]:match '^%s*$' then table.insert(ins, '') end
    api.nvim_buf_set_lines(0, last, last, false, ins)
    api.nvim_win_set_cursor(0, { last + 2, #head })
    return vim.cmd 'startinsert!'
  end
  local it = item_at(c, i)
  if it then
    local e = item_end(c, i)
    it.text, it.box = '', ' '
    if it.kind == 'number' then it.num = it.num + 1 end
    api.nvim_buf_set_lines(0, e, e, false, { fmt(it) })
    renumber()
    api.nvim_win_set_cursor(0, { e + 1, 0 })
    return vim.cmd 'startinsert!'
  end
  api.nvim_feedkeys('o', 'n', false)
end

-- <leader>- : plain → bullet → numbered → task → plain.
local NEXT = { plain = 'bullet', bullet = 'number', number = 'task', task = 'plain' }
local function cycle_list(s, e)
  local c = ctx()
  -- On an empty line: start a bullet list and type.
  if s == e and c.ls[s]:match '^%s*$' then
    set_line(s, c.ls[s] .. '- ')
    return vim.cmd 'startinsert!'
  end
  local target
  for j = s, e do
    if not c.code[j] and not heading_at(c, j) and not c.ls[j]:match '^%s*$' then
      local it = item_at(c, j)
      target = target or NEXT[it and it.kind or 'plain']
      it = it or { indent = #c.ls[j]:match '^%s*', text = (c.ls[j]:gsub('^%s*', '')) }
      if target == 'plain' then
        set_line(j, (' '):rep(it.indent) .. it.text)
      else
        it.kind, it.num, it.box = target, 1, ' '
        if it.bullet == nil then it.bullet = '-' end
        set_line(j, fmt(it))
      end
    end
  end
  renumber()
end

-- <leader># : toggle heading; a new heading takes the level of the one above.
local function toggle_heading()
  local c, i = ctx(), cur()
  if heading_at(c, i) then return set_heading(c, i, 0) end
  local lvl = 1
  for j = i - 1, 1, -1 do
    local h = heading_at(c, j)
    if h then
      lvl = h
      break
    end
  end
  set_heading(c, i, lvl)
  renumber()
end

local function goto_heading(dir)
  local c = ctx()
  local i = cur()
  for _ = 1, vim.v.count1 do
    local j = i + dir
    while j >= 1 and j <= #c.ls and not heading_at(c, j) do
      j = j + dir
    end
    if j < 1 or j > #c.ls then break end
    i = j
  end
  if i ~= cur() then
    set_jump()
    api.nvim_win_set_cursor(0, { i, 0 })
  end
end

local function goto_parent()
  local c, i = ctx(), cur()
  local h = heading_at(c, i) or 7
  for j = i - 1, 1, -1 do
    local hj = heading_at(c, j)
    if hj and hj < h then
      set_jump()
      return api.nvim_win_set_cursor(0, { j, 0 })
    end
  end
end

-- <S-Tab> : org-style global cycle. all open → overview (top level only) →
-- one level deeper → all open. Notes with an `# H1` title show their H2s on
-- the second press.
local function cycle_folds()
  local lvl = vim.wo.foldlevel
  vim.wo.foldlevel = lvl >= 2 and 0 or lvl == 0 and 1 or 99
  local names = { [0] = 'overview', [1] = 'one level', [99] = 'all open' }
  vim.api.nvim_echo({ { 'Folds: ' .. names[vim.wo.foldlevel] } }, false, {})
end

-- [[ Mappings ]] --------------------------------------------------------------

-- Attached on the next tick so these win over bullets.vim's and the builtin
-- markdown ftplugin's buffer maps (]] / [[), whatever the load order.
local function attach(buf)
  local function map(mode, lhs, rhs, desc, expr)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = 'MD: ' .. desc, expr = expr })
  end
  -- Dot-repeatable normal-mode action.
  local function rmap(lhs, fn, desc) map('n', lhs, repeatable(fn), desc, true) end

  rmap('>>', shift(1), 'Demote heading / indent line')
  rmap('<<', shift(-1), 'Promote heading / outdent line')
  map('x', '>', function() shift_visual(1) end, 'Demote headings / indent lines')
  map('x', '<', function() shift_visual(-1) end, 'Promote headings / outdent lines')
  rmap('>s', function() shift_tree(1) end, 'Demote subtree')
  rmap('<s', function() shift_tree(-1) end, 'Promote subtree')

  rmap('<leader>j', function() move(1) end, 'Move section / item down')
  rmap('<leader>k', function() move(-1) end, 'Move section / item up')
  map('n', '<leader><CR>', new_sibling, 'New sibling heading / item')

  map('n', '<leader>-', function() cycle_list(cur(), cur()) end, 'Cycle list type')
  map('x', '<leader>-', function() cycle_list(visual_range()) end, 'Cycle list type')
  rmap('<leader>#', toggle_heading, 'Toggle heading')
  for n = 0, 6 do
    rmap('<leader>m' .. n, function() set_heading(ctx(), cur(), n) end, n == 0 and 'Remove heading' or ('Heading level ' .. n))
  end

  map({ 'n', 'x', 'o' }, ']]', function() goto_heading(1) end, 'Next heading')
  map({ 'n', 'x', 'o' }, '[[', function() goto_heading(-1) end, 'Previous heading')
  map({ 'n', 'x', 'o' }, '[u', goto_parent, 'Up to parent heading')
  map({ 'n', 'x' }, 'gN', function() renumber() end, 'Renumber lists')
  map('n', '<S-Tab>', cycle_folds, 'Cycle folds: overview / one level / all')
end

api.nvim_create_autocmd('FileType', {
  group = api.nvim_create_augroup('markdown-structure', { clear = true }),
  pattern = 'markdown',
  callback = function(ev)
    -- Treesitter folds: sections, nested list items, code blocks. All open on load.
    vim.opt_local.foldmethod = 'expr'
    vim.opt_local.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
    vim.opt_local.foldtext = ''
    vim.opt_local.foldlevel = 99
    vim.schedule(function()
      if api.nvim_buf_is_valid(ev.buf) then attach(ev.buf) end
    end)
    -- Keep numbered lists correct after any edit: new items from <CR> / o,
    -- deleted or pasted lines. Runs once per normal-mode change and on
    -- leaving insert mode, not on every keystroke.
    api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave' }, {
      group = api.nvim_create_augroup('markdown-structure-renumber-' .. ev.buf, { clear = true }),
      buffer = ev.buf,
      callback = function() renumber(true) end,
    })
  end,
})

pcall(function() require('which-key').add { { '<leader>m', group = '[M]arkdown' } } end)
