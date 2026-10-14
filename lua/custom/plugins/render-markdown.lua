-- In-buffer markdown renderer: pretty headings, code blocks, tables,
-- checkboxes, callouts, etc. rendered inline as you edit.
-- Depends on the `markdown` + `markdown_inline` treesitter parsers (already
-- in the ensure_installed list) and nvim-web-devicons for icons.
vim.pack.add { 'https://github.com/MeanderingProgrammer/render-markdown.nvim' }

require('render-markdown').setup {
  -- Render in normal/command mode; show raw source while inserting or
  -- visually selecting so editing stays unobstructed.
  render_modes = { 'n', 'c', 't' },
  file_types = { 'markdown' },
  -- Default border = 'hide' conceals the closing ``` line entirely, which also
  -- hides snacks.image's inline mermaid render (attached as virt_lines there).
  code = { border = 'thin' },
  -- Keep the cursor line rendered in normal mode; raw source only shows in
  -- insert/visual (render_modes above excludes them).
  anti_conceal = { enabled = false },
  -- Tables are drawn by table-wrap.lua (wraps cells to fit the window).
  pipe_table = { enabled = false },
  -- Keep concealed text hidden on the cursor line in normal/command mode too,
  -- so moving the cursor never flips a line back to raw source.
  win_options = { concealcursor = { rendered = 'nc' } },
  -- Obsidian-ish headings: terminals can't change font size, so hierarchy comes
  -- from weight instead. H1/H2 get full-width bands framed by half-block borders;
  -- H3+ shrink to a tinted block around the text.
  heading = {
    sign = false,
    position = 'inline',
    icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
    width = { 'full', 'full', 'block' },
    left_pad = 1,
    right_pad = 2,
    border = { true, true, false },
    border_virtual = true, -- borders as virtual lines; never eat real blank lines
  },
}

-- Bold heading text; backgrounds are a faint tint of each level's color so the
-- band reads as a heading without shouting. Re-applied on colorscheme change.
local function heading_hl()
  local colors = { '#7aa2f7', '#bb9af7', '#7dcfff', '#9ece6a', '#e0af68', '#f7768e' }
  local bg = vim.api.nvim_get_hl(0, { name = 'Normal' }).bg or 0x1a1b26
  local function blend(hex, alpha)
    local c = tonumber(hex:sub(2), 16)
    local out = 0
    for shift = 16, 0, -8 do
      local a, b = bit.band(bit.rshift(c, shift), 0xff), bit.band(bit.rshift(bg, shift), 0xff)
      out = out + bit.lshift(math.floor(a * alpha + b * (1 - alpha) + 0.5), shift)
    end
    return out
  end
  for i, c in ipairs(colors) do
    local alpha = i <= 2 and 0.22 or 0.12
    vim.api.nvim_set_hl(0, 'RenderMarkdownH' .. i, { fg = c, bold = true })
    vim.api.nvim_set_hl(0, 'RenderMarkdownH' .. i .. 'Bg', { fg = c, bg = blend(c, alpha), bold = true })
  end
end
heading_hl()
vim.api.nvim_create_autocmd('ColorScheme', { callback = heading_hl })

-- Toggle the rendered view on/off.
vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown toggle<cr>', { desc = '[T]oggle [M]arkdown render' })

-- Tables wider than the window break when soft-wrapped (a render-markdown
-- limitation). Toggle wrap off to view them intact and scroll with zl/zh.
vim.keymap.set('n', '<leader>tw', function()
  vim.wo.wrap = not vim.wo.wrap
  vim.notify('wrap ' .. (vim.wo.wrap and 'on' or 'off'))
end, { desc = '[T]oggle [W]rap' })
