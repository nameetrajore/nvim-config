-- Debugging via nvim-dap. C# uses netcoredbg, built from source for arm64
-- (Mason only ships an x64 build, which can't debug native arm64 .NET processes).
vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
}

local dap = require 'dap'
local dapui = require 'dapui'

---@diagnostic disable-next-line: missing-fields
dapui.setup {
  icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
  ---@diagnostic disable-next-line: missing-fields
  controls = {
    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
      disconnect = '⏏',
    },
  },
}

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close

-- [[ C# / netcoredbg ]]
dap.adapters.coreclr = {
  type = 'executable',
  command = vim.fn.expand '~/.local/share/netcoredbg/netcoredbg',
  args = { '--interpreter=vscode' },
}

-- Builds the project containing the current file, then returns the path to its Debug dll.
local function build_and_find_dll()
  local csproj = vim.fs.find(function(name) return name:match '%.csproj$' end, { upward = true, path = vim.fn.expand '%:p:h' })[1]
  if not csproj then return vim.fn.input('Path to dll: ', vim.fn.getcwd() .. '/bin/Debug/', 'file') end

  local out = vim.fn.system { 'dotnet', 'build', csproj, '-c', 'Debug' }
  if vim.v.shell_error ~= 0 then
    vim.notify(out, vim.log.levels.ERROR)
    return dap.ABORT
  end

  local name = vim.fn.fnamemodify(csproj, ':t:r')
  local dlls = vim.fn.glob(vim.fs.dirname(csproj) .. '/bin/Debug/*/' .. name .. '.dll', false, true)
  return dlls[#dlls]
end

dap.configurations.cs = {
  {
    type = 'coreclr',
    name = 'Build & launch project',
    request = 'launch',
    program = build_and_find_dll,
    cwd = '${fileDirname}',
  },
  {
    -- Debug tests: run `VSTEST_HOST_DEBUG=1 dotnet test ...`, then pick the testhost PID it prints.
    type = 'coreclr',
    name = 'Attach to process (e.g. testhost)',
    request = 'attach',
    processId = function() return require('dap.utils').pick_process { filter = 'testhost' } end,
  },
}

vim.keymap.set('n', '<F5>', function() dap.continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F10>', function() dap.step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F11>', function() dap.step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F12>', function() dap.step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>db', function() dap.toggle_breakpoint() end, { desc = '[D]ebug: Toggle [B]reakpoint' })
vim.keymap.set('n', '<leader>dB', function() dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, { desc = '[D]ebug: Conditional [B]reakpoint' })
vim.keymap.set('n', '<leader>dc', function() dap.continue() end, { desc = '[D]ebug: Start/[C]ontinue' })
vim.keymap.set('n', '<leader>dt', function() dap.terminate() end, { desc = '[D]ebug: [T]erminate' })
vim.keymap.set('n', '<leader>du', function() dapui.toggle() end, { desc = '[D]ebug: Toggle [U]I' })
