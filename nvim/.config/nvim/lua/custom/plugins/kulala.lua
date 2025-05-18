return {
  'mistweaverco/kulala.nvim',
  keys = {
    { '<leader>Rs', desc = 'Send request' },
    { '<leader>Ra', desc = 'Send all requests' },
    { '<leader>Rb', desc = 'Open scratchpad' },
  },
  ft = { 'http', 'rest' },
  opts = {
    -- your configuration comes here
    global_keymaps = true,
    global_keymaps_prefix = '<leader>R',
    kulala_keymaps_prefix = '',
  },

  -- Add description for keymapping
  vim.api.nvim_set_keymap('n', '<leader>R', '', { desc = '[R]est Request' }),

  -- Use kulala for .http file extensions
  vim.filetype.add {
    extension = {
      ['http'] = 'http',
    },
  },
}
