-- Local plugin: ~/code/lexicon.nvim (dictionary + Wikipedia lookups)
if vim.fn.isdirectory(vim.fn.expand '~/code/lexicon.nvim') == 0 then return end
vim.opt.rtp:prepend(vim.fn.expand '~/code/lexicon.nvim')

require('lexicon').setup()
