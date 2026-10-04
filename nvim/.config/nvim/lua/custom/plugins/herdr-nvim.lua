return {
  'ChmaraX/herdr-nvim',

  opts = {},

  config = function()
    require('herdr-nvim').setup {
      prefix = '<leader>a', -- keymap prefix
      keymaps = false, -- set false to define your own
      clear_after_send = true, -- comments are ephemeral by design
    }
  end,

  keys = {
    {
      '<leader>a',
      '',
      desc = '[A]I Herdr-nvim',
    },
    {
      '<leader>ac',
      ':Herdr comment<CR>',
      desc = 'Herdr-nvim: [c]omment',
    },
    {
      '<leader>al',
      ':Herdr list<CR>',
      desc = 'Herdr-nvim [l]ist',
    },
    {
      '<leader>as',
      ':Herdr send<CR>',
      desc = 'Herdr-nvim [s]end',
    },
    {
      '<leader>aS',
      ':Herdr submit<CR>',
      desc = 'Herdr-nvim [S]ubmit',
    },
    {
      '<leader>ai',
      ':Herdr ref<CR>',
      desc = 'Herdr-nvim reference l[i]ne',
    },
  },
}
