-- Live markdown preview in the browser: spins up a local web server and opens
-- the current file, live-reloading on every save/edit. Complements
-- render-markdown.nvim (in-buffer) when you want real HTML — rendered mermaid
-- diagrams, KaTeX math, and a true page layout.
-- Pure Lua with a built-in server: no Node/Deno/yarn build step, so it slots
-- into this config's vim.pack (no-build) convention. Also previews AsciiDoc,
-- SVG, and HTML. Picker integration auto-detects Telescope (already loaded).
vim.pack.add { 'https://github.com/brianhuster/live-preview.nvim' }

require('livepreview.config').set {
  port = 5500,
  autokill = false,
  -- Pick the first available on this machine; falls back to $BROWSER / OS default.
  browser = 'default',
}

-- Toggle the browser preview for the current buffer on/off.
vim.keymap.set('n', '<leader>mp', '<cmd>LivePreview start<cr>', { desc = '[M]arkdown [P]review (browser)' })
vim.keymap.set('n', '<leader>ms', '<cmd>LivePreview close<cr>', { desc = '[M]arkdown preview [S]top' })
