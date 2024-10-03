return {
  'vim-test/vim-test',
  dependencies = {
    'preservim/vimux',
    dependencies = {
      'benmills/vimux-golang',
    },
  },

  vim.keymap.set('n', '<leader>v', '', { desc = '[V]im-Test ...' }),
  vim.keymap.set('n', '<leader>vn', ':TestNearest<CR>', { desc = 'Vim-Test Run [N]earest' }),
  vim.keymap.set('n', '<leader>vf', ':TestFile<CR>', { desc = 'Vim-Test Run [F]ile' }),
  vim.keymap.set('n', '<leader>vs', ':TestSuite<CR>', { desc = 'Vim-Test Run [S]uite' }),
  vim.keymap.set('n', '<leader>vl', ':TestLast<CR>', { desc = 'Vim-Test Run [L]ast' }),
  vim.keymap.set('n', '<leader>vv', ':TestVisit<CR>', { desc = 'Vim-Test Run [V]isit' }),

  vim.cmd "let test#strategy = 'vimux'",
  vim.cmd "let test#go#runner = 'gotest'",
  vim.cmd "let test#go#gotest#options = '-v -timeout 0 -count 1 -tags ci_jenkins'", -- -v: verbose, -timeout 0: infinite timeout, -count 1: non-cached run always, -tags ci_jenkins: run against CI setup.
}
