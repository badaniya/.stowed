return {
  --'vim-test/vim-test',
  --dependencies = {
  --  'preservim/vimux',
  --  dependencies = {
  --    'benmills/vimux-golang',
  --  },
  --},

  --vim.keymap.set('n', '<leader>T', '', { desc = 'Run [T]est' }),
  --vim.keymap.set('n', '<leader>Tn', ':TestNearest<CR>', { desc = 'Run [T]est [n]earest' }),
  --vim.keymap.set('n', '<leader>Tf', ':TestFile<CR>', { desc = 'Run [T]est [f]ile' }),
  --vim.keymap.set('n', '<leader>Ts', ':TestSuite<CR>', { desc = 'Run [T]est [s]uite' }),
  --vim.keymap.set('n', '<leader>Tl', ':TestLast<CR>', { desc = 'Run [T]est [l]ast' }),
  --vim.keymap.set('n', '<leader>Tv', ':TestVisit<CR>', { desc = 'Run [T]est [v]isit' }),

  --vim.cmd "let test#strategy = 'vimux'",
  --vim.cmd "let test#go#runner = 'gotest'",
  --vim.cmd "let test#go#gotest#options = '-v -timeout 0 -count 1 -tags ci_jenkins'", -- -v: verbose, -timeout 0: infinite timeout, -count 1: non-cached run always, -tags ci_jenkins: run against CI setup.
}
