return {
  {
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    config = function()
      require('dashboard').setup {
        -- config
        theme = 'hyper',
        config = {},
        hide = {
          statusline = true, -- hide statusline default is true
          tabline = true, -- hide the tabline
          winbar = true, -- hide winbar
        },
      }
    end,
    dependencies = { { 'nvim-tree/nvim-web-devicons' } },
  },
}
