return {
  'HakonHarnes/img-clip.nvim',
  event = 'VeryLazy',
  opts = {
    -- add options here
    -- or leave it empty to use the default settings
    codecompanion = {
      prompt_for_file_name = false,
      template = '[Image]($FILE_PATH)',
      use_absolute_path = true,
    },
  },
  keys = {
    -- suggested keymap
    { '<leader>p', '<cmd>PasteImage<cr>', desc = 'Paste image from system clipboard' },
  },
}
