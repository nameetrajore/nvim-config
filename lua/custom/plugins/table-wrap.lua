-- Wrapping table renderer for markdown. render-markdown draws tables in place, so
-- a table wider than the window soft-wraps and its borders fall apart. Instead,
-- draw the table sized to the window (long cells word-wrapped inside their
-- column) and paint each row over its raw line's wrapped screen rows.
--
-- Raw source comes back in insert/visual mode (we clear our drawing there).
-- render-markdown's own table rendering is disabled in render-markdown.lua so
-- the two don't overlap.

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

-- Display width; plain ASCII (the common case) skips the Vimscript call.
local function width(s)
  if not s:find '[\128-\255\t]' then return #s end
  return vim.fn.strdisplaywidth(s)
end

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
        if not word:find '[\128-\255\t]' then
          table.insert(out, word:sub(1, w))
          word = word:sub(w + 1)
        else
          local n = 0
          while width(vim.fn.strcharpart(word, 0, n + 1)) <= w do
            n = n + 1
          end
          table.insert(out, vim.fn.strcharpart(word, 0, n))
          word = vim.fn.strcharpart(word, n)
        end
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

  -- One spec per source line: `content` is the drawn row, `tail` the border
  -- that closes it, `above` (header only) the top border, `blank` an empty row
  -- used to pad when the raw line wraps onto more screen rows than are drawn.
  local function row_line(cols, line, is_head)
    local bhl = is_head and hl.head_border or hl.border
    local chunks = { { indent .. '│', bhl } }
    for i = 1, ncols do
      local text = pad(cols and cols[i][line] or '', widths[i], aligns[i])
      table.insert(chunks, { ' ' .. text .. ' ', is_head and hl.head or nil })
      table.insert(chunks, { '│', bhl })
    end
    return chunks
  end
  local blank = row_line(nil, 1, false)

  local specs = {}
  for r, row in ipairs(wrapped) do
    local is_head = r == 1
    local spec = { content = {}, tail = {}, blank = is_head and row_line(nil, 1, true) or blank }
    for line = 1, row.height do
      table.insert(spec.content, row_line(row.cols, line, is_head))
    end
    if is_head then
      spec.above = { border_line(indent, widths, '┌', '┬', '┐', hl.head_border) }
    elseif r == #wrapped then
      spec.tail = { border_line(indent, widths, '└', '┴', '┘', hl.border) }
    elseif multi then
      -- Separate rows only when some wrap; otherwise it's just noise.
      spec.tail = { border_line(indent, widths, '├', '┼', '┤', hl.border) }
    end
    table.insert(specs, spec)
    if is_head then
      -- Source line 2 is the delimiter row; it becomes the header separator.
      local sep = border_line(indent, widths, '├', '┼', '┤', hl.head_border)
      local tail = #wrapped == 1 and { border_line(indent, widths, '└', '┴', '┘', hl.border) } or {}
      table.insert(specs, { content = { sep }, tail = tail, blank = sep })
    end
  end
  return specs
end

-- Byte columns where each screen row of a wrapped line starts. Plain ASCII is
-- computed directly; anything else (multibyte, tabs, other plugins' inline
-- virtual text such as render-markdown's link icons) asks Neovim's own layout,
-- binary-searching each row boundary.
local function row_starts(win, row, line, first, rest, exact)
  rest = math.max(rest, 1)
  if not exact and not line:find '[\128-\255\t]' then
    local starts, col = { 0 }, first
    while col < #line do
      table.insert(starts, col)
      col = col + rest
    end
    return starts
  end
  local function height(opts)
    local h = vim.api.nvim_win_text_height(win, vim.tbl_extend('force', { start_row = row, end_row = row }, opts or {}))
    return h.all - h.fill
  end
  -- 0-based screen row holding the character at byte `col`.
  local function row_of(col)
    local vstart = vim.fn.virtcol({ row + 1, col + 1 }, true, win)[1]
    return height { end_vcol = vstart } - 1
  end
  local pos = vim.str_utf_pos(line)
  local starts, lo = { 0 }, 1
  for j = 1, height() - 1 do
    local hi = #pos
    while lo < hi do
      local mid = math.floor((lo + hi) / 2)
      if row_of(pos[mid] - 1) >= j then
        hi = mid
      else
        lo = mid + 1
      end
    end
    table.insert(starts, pos[lo] - 1)
  end
  return starts
end

-- Per-buffer state: the inputs of the last render (to skip redundant ones) and
-- caches of drawn tables / wrap points keyed by their inputs. Each render keeps
-- only the entries it used, so stale ones drop out.
local state = {}

local function render(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    state[buf] = nil
    return
  end
  local st = state[buf] or { builds = {}, starts = {} }
  state[buf] = st

  local win = vim.fn.win_findbuf(buf)[1]
  local mode = vim.api.nvim_get_mode().mode:sub(1, 1)
  -- Raw source while editing or selecting.
  local active = win and not (vim.api.nvim_get_current_buf() == buf and not (mode == 'n' or mode == 'c'))
  if not active then
    if st.sig then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      st.sig = nil
    end
    return
  end

  local info = vim.fn.getwininfo(win)[1]
  local avail = info.width - info.textoff
  local wrap_on = vim.wo[win].wrap
  local showbreak = width(vim.wo[win].showbreak ~= '' and vim.wo[win].showbreak or vim.o.showbreak)
  local breakindent = vim.wo[win].breakindent

  -- Other plugins' inline virtual text (render-markdown's link icons) moves wrap
  -- points, so it is part of the input. One query for the whole buffer.
  local foreign, foreign_sig = {}, {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf, -1, 0, -1, { details = true, type = 'virt_text' })) do
    local d = m[4]
    if d.ns_id ~= ns and d.virt_text_pos == 'inline' then
      local w = 0
      for _, chunk in ipairs(d.virt_text) do
        w = w + width(chunk[1])
      end
      foreign[m[2]] = (foreign[m[2]] or '') .. m[3] .. ':' .. w .. ','
      table.insert(foreign_sig, m[2] .. '/' .. m[3] .. ':' .. w)
    end
  end

  -- Only rows near the window are drawn: the visible range plus one window
  -- height either side, extended as the view scrolls past it.
  local top, bot = info.topline - 1, info.botline - 1
  local sig = table.concat({ vim.b[buf].changedtick, avail, tostring(wrap_on), showbreak, tostring(breakindent), table.concat(foreign_sig, ',') }, '|')
  if sig == st.sig and top >= st.r0 and bot <= st.r1 then return end
  local margin = info.height
  st.sig, st.r0, st.r1 = sig, math.max(0, top - margin), bot + margin

  local ok, parser = pcall(vim.treesitter.get_parser, buf, 'markdown')
  if not ok or not parser then return end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local builds, starts_cache = {}, {}
  local function mark(row, col, opts) vim.api.nvim_buf_set_extmark(buf, ns, row, col, opts) end

  for _, node in query:iter_captures(parser:parse()[1]:root(), buf, st.r0, st.r1 + 1) do
    local srow, _, erow, ecol = node:range()
    if ecol == 0 then erow = erow - 1 end
    local lines = vim.api.nvim_buf_get_lines(buf, srow, erow + 1, false)
    local bkey = avail .. '\0' .. table.concat(lines, '\n')
    local specs = st.builds[bkey]
    if specs == nil then specs = build(lines, avail - 1) or false end
    builds[bkey] = specs
    for k, spec in ipairs(specs or {}) do
      if srow + k - 1 < st.r0 or srow + k - 1 > st.r1 then goto continue end
      -- Every raw line stays a real line and its drawing is painted over it, one
      -- overlay per screen row the raw text wraps onto. No concealing: wrapped
      -- height counts concealed text anyway, and keeping real lines means each
      -- row scrolls (and takes the cursor) on its own. Rows drawn taller than
      -- the raw text spill into virtual lines below; shorter ones pad with blanks.
      local row, line = srow + k - 1, lines[k]
      local indent = line:match '^%s*'
      local bri = breakindent and width(indent) or 0
      local starts = { 0 }
      if wrap_on then
        local rest = avail - bri - showbreak
        local skey = table.concat({ avail, rest, foreign[row] or '', line }, '\0')
        starts = st.starts[skey] or row_starts(win, row, line, avail, rest, foreign[row] ~= nil)
        starts_cache[skey] = starts
      end

      local seq = vim.list_extend({}, spec.content)
      while #seq + #spec.tail < #starts do
        table.insert(seq, spec.blank)
      end
      vim.list_extend(seq, spec.tail)

      local pad_chunk = { string.rep(' ', avail) }
      for j, col in ipairs(starts) do
        local chunks = seq[j]
        -- breakindent already indents continuation rows.
        if j > 1 and bri > 0 then
          chunks = vim.deepcopy(chunks)
          chunks[1][1] = chunks[1][1]:sub(#indent + 1)
        end
        -- Pad to full width so the overlay covers every raw character.
        chunks = { unpack(chunks) }
        table.insert(chunks, pad_chunk)
        mark(row, col, { virt_text = chunks, virt_text_pos = 'overlay' })
      end
      local spill = { unpack(seq, #starts + 1) }
      if #spill > 0 then mark(row, 0, { virt_lines = spill }) end
      if spec.above then mark(row, 0, { virt_lines = spec.above, virt_lines_above = true }) end
      ::continue::
    end
  end
  st.builds, st.starts = builds, starts_cache
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
    vim.api.nvim_create_autocmd({ 'BufWinEnter', 'TextChanged', 'InsertLeave', 'ModeChanged', 'WinScrolled', 'WinResized', 'VimResized' }, {
      group = group,
      buffer = buf,
      callback = function() schedule(buf) end,
    })
    schedule(buf)
  end,
})
-- render-markdown adds inline virtual text (link icons) that moves wrap points,
-- so redraw after each of its renders (fired from its `on.render` hook).
vim.api.nvim_create_autocmd('User', {
  group = group,
  pattern = 'RenderMarkdownRendered',
  callback = function(ev) schedule(ev.data.buf) end,
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
vim.api.nvim_create_autocmd('BufWipeout', {
  group = group,
  callback = function(ev) state[ev.buf] = nil end,
})
