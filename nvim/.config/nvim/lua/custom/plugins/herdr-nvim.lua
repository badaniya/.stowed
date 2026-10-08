return {
  'ChmaraX/herdr-nvim',

  opts = {},

  config = function()
    require('herdr-nvim').setup {
      prefix = '<leader>a', -- keymap prefix
      keymaps = true, -- set false to define your own
      clear_after_send = true, -- comments are ephemeral by design
    }
  end,

  keys = {
    { '<leader>a', '', desc = '[A]I Herdr-nvim', mode = { 'n', 'x' } },
    { '<leader>ac', '<CMD>Herdr comment<CR>', desc = 'Herdr comment' },
    { '<leader>ac', ':Herdr comment<CR>', desc = 'Herdr comment selection', mode = 'x' },
    { '<leader>al', '<CMD>Herdr list<CR>', desc = 'Herdr list comments' },
    { '<leader>as', '<CMD>Herdr send<CR>', desc = 'Herdr paste comments to agent' },
    { '<leader>aS', '<CMD>Herdr submit<CR>', desc = 'Herdr submit comments to agent' },
    { '<leader>ai', '<CMD>Herdr ref<CR>', desc = 'Herdr reference line' },
    { '<leader>ai', ':Herdr ref<CR>', desc = 'Herdr reference selection', mode = 'x' },
  },
}
