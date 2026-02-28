return {
  'dhruvasagar/vim-prosession',
  dependencies = {
    'tpope/vim-obsession',
  },

  vim.keymap.set('n', '<leader>sp', ':Telescope prosession<CR>', { desc = '[S]earch [P]rosession' }),
}
