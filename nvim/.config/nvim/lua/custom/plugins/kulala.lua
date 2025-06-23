return {
  'mistweaverco/kulala.nvim',
  keys = {
    { '<leader>Ks', desc = 'Send request' },
    { '<leader>Ka', desc = 'Send all requests' },
    { '<leader>Kb', desc = 'Open scratchpad' },
  },
  ft = { 'http', 'rest' },
  opts = {
    -- your configuration comes here
    global_keymaps = true,
    global_keymaps_prefix = '<leader>K',
    kulala_keymaps_prefix = '',
  },

  -- Use kulala for .http file extensions
  vim.filetype.add {
    extension = {
      ['http'] = 'http',
    },
  },
}
