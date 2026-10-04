return {
  'vim-test/vim-test',
  dependencies = {
    'willian/vim-test-herdr',
    'preservim/vimux',
    dependencies = {
      'benmills/vimux-golang',
    },
  },

  config = function()
    vim.g['test#strategy'] = vim.env.HERDR_ENV == '1' and 'herdr' or 'vimux'
    vim.g['test#go#runner'] = 'gotest'
    vim.g['test#gotest#options'] = '-v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all' -- -v: verbose, -timeout 0: infinite timeout, -count 1: non-cached run always, -tags ci_jenkins: run against CI setup.
  end,

  keys = {
    {
      '<leader>v',
      '',
      desc = '[V]im-Test',
    },
    {
      '<leader>vn',
      ':TestNearest<CR>',
      desc = '[V]im-Test Run [N]earest',
    },
    {
      '<leader>vf',
      ':TestFile<CR>',
      desc = '[V]im-Test Run [F]ile',
    },
    {
      '<leader>vs',
      ':TestSuite<CR>',
      desc = '[V]im-Test Run [S]uite',
    },
    {
      '<leader>vl',
      ':TestLast<CR>',
      desc = '[V]im-Test Run [L]ast',
    },
    {
      '<leader>vv',
      ':TestVisit<CR>',
      desc = '[V]im-Test Run [V]isit',
    },
    {
      '<leader>vc',
      function()
        vim.cmd(vim.env.HERDR_ENV == '1' and 'HerdrCloseRunner' or 'VimuxCloseRunner')
      end,
      desc = '[V]im-Test Run [C]lose Pane',
    },
  },
}
