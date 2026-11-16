-- Local plugin: ~/code/switchyard (agent workflows as visible state machines)
if vim.fn.isdirectory(vim.fn.expand '~/code/switchyard') == 0 then return end
-- Panel: :Switchyard  ·  in panel: gd open node, f fix node, r run, c check, ? help
vim.opt.rtp:prepend(vim.fn.expand '~/code/switchyard')
vim.g.switchyard_no_setup = true
vim.cmd 'runtime plugin/switchyard.lua'

require('switchyard').setup {}

vim.keymap.set('n', '<leader>Sv', '<cmd>Switchyard<cr>', { desc = '[S]witchyard [V]iew' })
vim.keymap.set('n', '<leader>Sr', '<cmd>SwitchyardRun<cr>', { desc = '[S]witchyard [R]un' })
vim.keymap.set('n', '<leader>Sc', '<cmd>SwitchyardCheck<cr>', { desc = '[S]witchyard [C]heck' })
pcall(function() require('which-key').add { { '<leader>S', group = '[S]witchyard' } } end)

-- Execute a ticket: pick the ticket folder and the repo, then plan → approve (a/x in panel) → implement → PR
vim.keymap.set('n', '<leader>St', function()
  local cwd_repo = vim.fs.root(0, '.git') or vim.fn.getcwd()
  vim.ui.input({ prompt = 'Ticket folder: ', completion = 'dir' }, function(ticket)
    if not ticket or ticket == '' then return end
    vim.ui.input({ prompt = 'Repo: ', default = cwd_repo, completion = 'dir' }, function(repo)
      if not repo or repo == '' then return end
      require('switchyard').start(vim.fn.expand '~/code/switchyard/flows/execute-ticket/machine.ts', {
        ticket = vim.fn.fnamemodify(vim.fn.expand(ticket), ':p'),
        repo = vim.fn.fnamemodify(vim.fn.expand(repo), ':p'),
      })
    end)
  end)
end, { desc = '[S]witchyard execute [T]icket' })
