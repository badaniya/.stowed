return {
  'folke/trouble.nvim',
  opts = {}, -- for default options, refer to the configuration section for custom setup.
  cmd = 'Trouble',
  keys = {
    {
      '<leader>t',
      '',
      desc = '[T]rouble',
    },
    {
      '<leader>td',
      '<cmd>Trouble diagnostics toggle<cr>',
      desc = '[T]rouble [D]iagnostics',
    },
    {
      '<leader>tb',
      '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
      desc = '[T]rouble Diagnostic [B]uffer',
    },
    {
      '<leader>ts',
      '<cmd>Trouble symbols toggle focus=false win.position=right win.size=.25<cr>',
      desc = '[T]rouble [S]ymbols',
    },
    {
      '<leader>tl',
      '<cmd>Trouble lsp toggle focus=false win.position=right win.size=.25<cr>',
      desc = '[T]rouble [L]SP Definitions / references / ...',
    },
    {
      '<leader>tL',
      '<cmd>Trouble loclist toggle<cr>',
      desc = '[T]rouble [L]ocation List',
    },
    {
      '<leader>tq',
      '<cmd>Trouble qflist toggle<cr>',
      desc = '[T]rouble [Q]uickfix List',
    },
  },
}
