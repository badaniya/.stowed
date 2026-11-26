return {
  'ChmaraX/herdr-nvim',
  lazy = false, -- Configure before Herdr's VimEnter fallback enables default keymaps

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
      mode = { 'n', 'x' },
    },
    {
      '<leader>ac',
      '<CMD>Herdr comment<CR>',
      desc = 'Herdr comment',
      mode = 'n',
    },
    {
      '<leader>ac',
      function()
        require('herdr-nvim').comment_selection()
      end,
      desc = 'Herdr comment selection',
      mode = 'x',
    },
    {
      '<leader>al',
      '<CMD>Herdr list<CR>',
      desc = 'Herdr list comments',
      mode = 'n',
    },
    {
      '<leader>as',
      '<CMD>Herdr send<CR>',
      desc = 'Herdr paste comments to agent',
      mode = 'n',
    },
    {
      '<leader>aS',
      '<CMD>Herdr submit<CR>',
      desc = 'Herdr submit comments to agent',
      mode = 'n',
    },
    {
      '<leader>ai',
      '<CMD>Herdr ref<CR>',
      desc = 'Herdr reference line',
      mode = 'n',
    },
    {
      '<leader>ai',
      function()
        require('herdr-nvim').ref_selection()
      end,
      desc = 'Herdr reference selection',
      mode = 'x',
    },
  },
}
