-- Wrapping table renderer for markdown. render-markdown draws tables in place, so
-- a table wider than the window soft-wraps and its borders fall apart. Instead,
-- hide the raw table lines (`conceal_lines`, nvim >= 0.11) and draw the table as
-- virtual lines sized to the window, word-wrapping long cells inside their column.
--
-- Raw source comes back in insert/visual mode (render-markdown resets
-- conceallevel there, and we clear our drawing). render-markdown's own table
-- rendering is disabled in render-markdown.lua so the two don't overlap.

local ns = vim.api.nvim_create_namespace 'table_wrap'
local query = vim.treesitter.query.parse('markdown', '(pipe_table) @table')

local hl = {
  border = 'RenderMarkdownTableRow',
  head_border = 'RenderMarkdownTableHead',
  head = '@markup.strong',
}

-- Split a table row on unescaped pipes that aren't inside `code`.
local function split_row(line)
  line = vim.trim(line):gsub('^|', ''):gsub('|$', '')
  local cells, cur, in_code, i = {}, {}, false, 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == '\\' and line:sub(i + 1, i + 1) == '|' then
      table.insert(cur, '|')
      i = i + 1
    elseif c == '`' then
      in_code = not in_code
      table.insert(cur, c)
    elseif c == '|' and not in_code then
      table.insert(cells, vim.trim(table.concat(cur)))
      cur = {}
    else
      table.insert(cur, c)
    end
    i = i + 1
  end
  table.insert(cells, vim.trim(table.concat(cur)))
  return cells
end

-- Strip inline markdown down to what it would read as.
local function clean(text)
  text = text:gsub('%[%[([^%]]-)|([^%]]-)%]%]', '%2') -- [[target|alias]] -> alias
  text = text:gsub('%[%[([^%]]-)%]%]', '%1') -- [[target]] -> target
  text = text:gsub('!?%[([^%]]-)%]%([^%)]-%)', '%1') -- [text](url) -> text
  text = text:gsub('%*%*(.-)%*%*', '%1'):gsub('__(.-)__', '%1')
  text = text:gsub('`([^`]-)`', '%1')
  return text
end

local width = vim.fn.strdisplaywidth

-- Greedy word wrap to `w` display columns; <br> forces a break, over-long words
-- are split by character.
local function wrap(text, w)
  local out = {}
  for para in (text .. '<br>'):gmatch '(.-)<br%s*/?>' do
    local line = ''
    for word in para:gmatch '%S+' do
      while width(word) > w do
        if line ~= '' then
          table.insert(out, line)
          line = ''
        end
        local n = 0
        while width(vim.fn.strcharpart(word, 0, n + 1)) <= w do
          n = n + 1
        end
        table.insert(out, vim.fn.strcharpart(word, 0, n))
        word = vim.fn.strcharpart(word, n)
      end
      if line == '' then
        line = word
      elseif width(line) + 1 + width(word) <= w then
        line = line .. ' ' .. word
      else
        table.insert(out, line)
        line = word
      end
    end
    table.insert(out, line)
  end
  return out
end

local function pad(text, w, align)
  local gap = w - width(text)
  if align == 'right' then return string.rep(' ', gap) .. text end
  if align == 'center' then
    local l = math.floor(gap / 2)
    return string.rep(' ', l) .. text .. string.rep(' ', gap - l)
  end
  return text .. string.rep(' ', gap)
end

-- Fit columns into `avail` cells: columns narrower than an even share keep their
-- natural width, the rest split what's left (water-filling).
local function fit(natural, avail)
  local total = 0
  for _, n in ipairs(natural) do
    total = total + n
  end
  if total <= avail then return vim.deepcopy(natural) end
  local widths, open, remaining = {}, {}, avail
  for i = 1, #natural do
    open[i] = true
  end
  local changed = true
  while changed do
    changed = false
    local count = vim.tbl_count(open)
    if count == 0 then break end
    local share = math.floor(remaining / count)
    for i in pairs(open) do
      if natural[i] <= share then
        widths[i], open[i], remaining, changed = natural[i], nil, remaining - natural[i], true
      end
    end
  end
  local rest = vim.tbl_keys(open)
  table.sort(rest)
  for k, i in ipairs(rest) do
    widths[i] = math.max(1, math.floor(remaining / #rest) + (k <= remaining % #rest and 1 or 0))
  end
  return widths
end

local function border_line(indent, widths, l, m, r, hlg)
  local parts = {}
  for i, w in ipairs(widths) do
    parts[i] = string.rep('─', w + 2)
  end
  return { { indent .. l .. table.concat(parts, m) .. r, hlg } }
end

-- Build virtual lines for one table, or nil if it can't be drawn sensibly.
local function build(lines, avail)
  local indent = lines[1]:match '^%s*'
  local header = split_row(lines[1])
  local delim = split_row(lines[2] or '')
  local ncols = #header
  if ncols == 0 or #delim ~= ncols then return nil end

  local aligns = {}
  for i, d in ipairs(delim) do
    local left, right = d:sub(1, 1) == ':', d:sub(-1) == ':'
    aligns[i] = (left and right) and 'center' or right and 'right' or 'left'
  end

  local rows = { header }
  for k = 3, #lines do
    local cells = split_row(lines[k])
    for i = 1, ncols do
      cells[i] = cells[i] or ''
    end
    table.insert(rows, cells)
  end

  local natural = {}
  for i = 1, ncols do
    natural[i] = 1
  end
  for r, cells in ipairs(rows) do
    for i = 1, ncols do
      cells[i] = clean(cells[i])
      for _, piece in ipairs(vim.split(cells[i], '<br%s*/?>')) do
        natural[i] = math.max(natural[i], width(vim.trim(piece)))
      end
    end
    rows[r] = cells
  end

  -- Borders + one space of padding either side of each cell.
  local inner = avail - width(indent) - (ncols + 1) - 2 * ncols
  if inner < ncols * 3 then return nil end
  local widths = fit(natural, inner)

  local wrapped, multi = {}, false
  for r, cells in ipairs(rows) do
    local cols, height = {}, 1
    for i = 1, ncols do
      cols[i] = wrap(cells[i], widths[i])
      height = math.max(height, #cols[i])
    end
    multi = multi or height > 1
    wrapped[r] = { cols = cols, height = height }
  end

  local out = { border_line(indent, widths, '┌', '┬', '┐', hl.head_border) }
  for r, row in ipairs(wrapped) do
    local is_head = r == 1
    local bhl = is_head and hl.head_border or hl.border
    for line = 1, row.height do
      local chunks = { { indent .. '│', bhl } }
      for i = 1, ncols do
        local text = pad(row.cols[i][line] or '', widths[i], aligns[i])
        table.insert(chunks, { ' ' .. text .. ' ', is_head and hl.head or nil })
        table.insert(chunks, { '│', bhl })
      end
      table.insert(out, chunks)
    end
    if is_head then
      table.insert(out, border_line(indent, widths, '├', '┼', '┤', hl.head_border))
    elseif r < #wrapped and multi then
      -- Separate rows only when some wrap; otherwise it's just noise.
      table.insert(out, border_line(indent, widths, '├', '┼', '┤', hl.border))
    end
  end
  table.insert(out, border_line(indent, widths, '└', '┴', '┘', hl.border))
  return out
end

local function render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  local win = vim.fn.win_findbuf(buf)[1]
  if not win then return end
  -- Raw source while editing or selecting.
  local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
  if vim.api.nvim_get_current_buf() == buf and not (mode == 'n' or mode == 'c') then return end

  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'markdown')
  if not ok or not parser then return end
  local info = vim.fn.getwininfo(win)[1]
  local avail = info.width - info.textoff
  local last_line = vim.api.nvim_buf_line_count(buf) - 1

  for _, node in query:iter_captures(parser:parse()[1]:root(), buf, 0, -1) do
    local srow, _, erow, ecol = node:range()
    if ecol == 0 then erow = erow - 1 end
    local lines = vim.api.nvim_buf_get_lines(buf, srow, erow + 1, false)
    local virt = build(lines, avail)
    -- Virtual lines on a concealed line are hidden too, so anchor them on a
    -- visible neighbour: above the next line, else below the previous one.
    local anchor, above
    if erow < last_line then
      anchor, above = erow + 1, true
    elseif srow > 0 then
      anchor, above = srow - 1, false
    end
    if virt and anchor then
      for row = srow, erow do
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { conceal_lines = '' })
      end
      vim.api.nvim_buf_set_extmark(buf, ns, anchor, 0, { virt_lines = virt, virt_lines_above = above })
    end
  end
end

local pending = {}
local function schedule(buf)
  if pending[buf] then return end
  pending[buf] = true
  vim.defer_fn(function()
    pending[buf] = nil
    render(buf)
  end, 50)
end

local group = vim.api.nvim_create_augroup('table_wrap', { clear = true })
vim.api.nvim_create_autocmd('FileType', {
  group = group,
  pattern = 'markdown',
  callback = function(ev)
    local buf = ev.buf
    vim.api.nvim_create_autocmd({ 'BufWinEnter', 'TextChanged', 'InsertLeave', 'ModeChanged', 'WinResized', 'VimResized' }, {
      group = group,
      buffer = buf,
      callback = function() schedule(buf) end,
    })
    schedule(buf)
  end,
})
-- WinResized fires for the resized windows' buffers, not necessarily the
-- current one, so also catch it globally.
vim.api.nvim_create_autocmd({ 'WinResized', 'VimResized' }, {
  group = group,
  callback = function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == 'markdown' then schedule(buf) end
    end
  end,
})
