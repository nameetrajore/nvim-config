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
  -- Root the server at the previewed file's OWN directory (and open /<basename>)
  -- instead of nvim's cwd. Without this, previewing a file outside cwd — e.g. an
  -- Obsidian vault note — yields a 404 /nil, since the URL path is computed
  -- relative to cwd and comes back nil when the file isn't under it.
  dynamic_root = true,
  -- Pick the first available on this machine; falls back to $BROWSER / OS default.
  browser = 'default',
}

-- WORKAROUND (fd leak / EMFILE): live-preview.nvim's Server:stop() closes only the
-- listening socket and the fs watcher. It never closes the accepted client sockets
-- tracked in the module-level `server.connecting_clients`, nor clears that table.
-- Each browser (re)connection appends a uv_tcp_t that outlives every restart, so over
-- a long session the open handles pile up until the process hits its fd ceiling and
-- the next spawn fails with EMFILE (fatal on macOS's default soft maxfiles of 256).
-- Wrap the module's close() to drain those sockets ourselves. start() calls close()
-- via the same module-table field, so this covers restarts too. Remove if upstream fixes.
do
  local lp = require 'livepreview'
  local server = require 'livepreview.server'
  local orig_close = lp.close
  lp.close = function(...)
    local ret = orig_close(...)
    for _, client in ipairs(server.connecting_clients or {}) do
      pcall(function()
        if client and not client:is_closing() then
          client:close()
        end
      end)
    end
    server.connecting_clients = {}
    return ret
  end
end

-- Toggle the browser preview for the current buffer on/off.
vim.keymap.set('n', '<leader>mp', '<cmd>LivePreview start<cr>', { desc = '[M]arkdown [P]review (browser)' })
vim.keymap.set('n', '<leader>ms', '<cmd>LivePreview close<cr>', { desc = '[M]arkdown preview [S]top' })
