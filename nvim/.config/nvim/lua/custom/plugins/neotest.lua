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
          go_test_args = {
            '-v', -- -v: verbose
            '-timeout=0', -- -timeout 0: infinite timeout
            '-count=1', -- -count 1: non-cached run always
            '-tags=ci_jenkins', -- -tags ci_jenkins: run against CI setup
            '-coverprofile=' .. vim.fn.getcwd() .. '/coverage.out', -- -coverprofile ./coverage.out generates a code coverage report
            '-covermode=atomic',
            '-coverpkg=all',
          },
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

    -- set debug level after having called require("neotest").setup()
    -- require('neotest.logging'):set_level(vim.log.levels.DEBUG)
  end,

  keys = {
    {
      '<leader>n',
      '',
      desc = '[N]eotest',
    },
    {
      '<leader>nf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = '[N]eotest Run [F]ile',
    },
    {
      '<leader>nt',
      function()
        require('neotest').run.run(vim.loop.cwd())
      end,
      desc = '[N]eotest Run All [T]est Files',
    },
    {
      '<leader>nn',
      function()
        require('neotest').run.run()
      end,
      desc = '[N]eotest Run [N]earest',
    },
    {
      '<leader>ns',
      function()
        require('neotest').summary.toggle()
      end,
      desc = '[N]eotest Toggle [S]ummary',
    },
    {
      '<leader>no',
      function()
        require('neotest').output.open { enter = true, auto_close = true }
      end,
      desc = '[N]eotest Show [O]utput',
    },
    {
      '<leader>np',
      function()
        require('neotest').output_panel.toggle()
      end,
      desc = '[N]eotest Toggle Output [P]anel',
    },
    {
      '<leader>ne',
      function()
        require('neotest').run.stop()
      end,
      desc = '[N]eotest [E]xit',
    },
    {
      '<leader>nd',
      function()
        require('dap-go').debug_test()
      end,
      desc = '[N]eotest [D]ebug Nearest Test',
    },
  },
}
