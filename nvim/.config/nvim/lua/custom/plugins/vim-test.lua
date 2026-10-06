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
    local module_root = require 'custom.vim-test-root'

    _G.ModuleAwareVimTestStrategy = module_root.run_strategy
    vim.cmd [[
      function! ModuleAwareVimTestStrategy(command) abort
        call v:lua.ModuleAwareVimTestStrategy(a:command)
      endfunction
      let g:test#custom_strategies.module_aware = function('ModuleAwareVimTestStrategy')
    ]]

    vim.g['test#strategy'] = 'module_aware'
    vim.g['test#go#runner'] = 'gotest'
    vim.g['test#project_root'] = module_root.current_buffer_root
    vim.api.nvim_create_user_command('TestLast', function(options)
      vim.g.vim_test_replaying_last = true
      local ok, err = pcall(vim.fn['test#run_last'], vim.fn.split(options.args))
      vim.g.vim_test_replaying_last = false
      if not ok then
        error(err)
      end
    end, { nargs = '*', bar = true, force = true })
    vim.g['test#go#gotest#options'] = '-v -timeout 0 -count 1 -tags ci_jenkins -coverprofile=coverage.out -covermode=atomic -coverpkg=all' -- -v: verbose, -timeout 0: infinite timeout, -count 1: non-cached run always, -tags ci_jenkins: run against CI setup.
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
