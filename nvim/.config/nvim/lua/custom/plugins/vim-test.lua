return {
  'vim-test/vim-test',
  dependencies = {
    'preservim/vimux',
    dependencies = {
      'benmills/vimux-golang',
    },
  },

  vim.keymap.set('n', '<leader>v', '', { desc = '[V]im-Test' }),
  vim.keymap.set('n', '<leader>vn', ':TestNearest<CR>', { desc = '[V]im-Test Run [N]earest' }),
  vim.keymap.set('n', '<leader>vf', ':TestFile<CR>', { desc = '[V]im-Test Run [F]ile' }),
  vim.keymap.set('n', '<leader>vs', ':TestSuite<CR>', { desc = '[V]im-Test Run [S]uite' }),
  vim.keymap.set('n', '<leader>vl', ':TestLast<CR>', { desc = '[V]im-Test Run [L]ast' }),
  vim.keymap.set('n', '<leader>vv', ':TestVisit<CR>', { desc = '[V]im-Test Run [V]isit' }),

  vim.cmd "let test#strategy = 'vimux'",
  vim.cmd "let test#go#runner = 'gotest'",
  vim.cmd "let test#go#gotest#options = '-v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all'", -- -v: verbose, -timeout 0: infinite timeout, -count 1: non-cached run always, -tags ci_jenkins: run against CI setup.
}
