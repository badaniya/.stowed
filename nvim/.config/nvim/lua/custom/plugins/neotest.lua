return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',
    { 'fredrikaverpil/neotest-golang', version = '*' }, -- Installation
  },
  config = function()
    require('neotest').setup {
      adapters = {
        require 'neotest-golang' { -- Registration
          go_test_args = { '-v', '-timeout=0', '-count=1', '-tags=ci_jenkins' }, -- -v: verbose, -timeout 0: infinite timeout, -count 1: non-cached run always, -tags ci_jenkins: run against CI setup.
          go_list_args = { '-tags=ci_jenkins' },
          dap_go_opts = {
            delve = {
              build_flags = { '-tags=ci_jenkins' },
            },
          },

          -- experimental
          dev_notifications = true,
          runner = 'gotestsum',
          gotestsum_args = { '--format=standard-verbose' },
          -- testify_enabled = true,
        },
      },
    }
  end,

  keys = {
    {
      '<leader>nt',
      '',
      desc = '[N]eo[t]est',
    },
    {
      '<leader>ntf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = 'Neotest Run [F]ile',
    },
    {
      '<leader>ntt',
      function()
        require('neotest').run.run(vim.loop.cwd())
      end,
      desc = 'Neotest Run All [T]est Files',
    },
    {
      '<leader>ntr',
      function()
        require('neotest').run.run()
      end,
      desc = 'Neotest [R]un Nearest',
    },
    {
      '<leader>nts',
      function()
        require('neotest').summary.toggle()
      end,
      desc = 'Neotest Toggle [S]ummary',
    },
    {
      '<leader>nto',
      function()
        require('neotest').output.open { enter = true, auto_close = true }
      end,
      desc = 'Neotest Show [O]utput',
    },
    {
      '<leader>ntp',
      function()
        require('neotest').output_panel.toggle()
      end,
      desc = 'Neotest Toggle Output [P]anel',
    },
    {
      '<leader>nte',
      function()
        require('neotest').run.stop()
      end,
      desc = 'Neotest [E]xit',
    },
    {
      '<leader>ntd',
      function()
        require('dap-go').debug_test()
      end,
      desc = 'Neotest [D]ebug Nearest Test',
    },
  },
}
