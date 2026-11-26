return {
  'jubnzv/mdeval.nvim',
  config = function()
    require('mdeval').setup {
      -- Don't ask before executing code blocks
      require_confirmation = false,
      -- Change code blocks evaluation options.
      eval_options = {},
    }
  end,

  vim.api.nvim_set_keymap('n', '<leader>ce', "<cmd>lua require 'mdeval'.eval_code_block()<CR>", { desc = '[C]ode [E]val', silent = true, noremap = true }),
}
