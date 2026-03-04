return {
  'Wansmer/treesj',
  -- Define custom keybinding with descriptions below instead of using the default keys input
  --keys = { '<space>ct', '<space>cj', '<space>cs' },
  dependencies = { 'nvim-treesitter/nvim-treesitter' }, -- if you install parsers with `nvim-treesitter`
  config = function()
    require('treesj').setup {--[[ your config ]]
      ---@type boolean Use default keymaps (<space>m - toggle, <space>j - join, <space>s - split)
      use_default_keymaps = false,
      ---@type boolean Node with syntax error will not be formatted
      check_syntax_error = true,
      ---If line after join will be longer than max value,
      ---@type number If line after join will be longer than max value, node will not be formatted
      max_join_length = 120,
      ---Cursor behavior:
      ---hold - cursor follows the node/place on which it was called
      ---start - cursor jumps to the first symbol of the node being formatted
      ---end - cursor jumps to the last symbol of the node being formatted
      ---@type 'hold'|'start'|'end'
      cursor_behavior = 'hold',
      ---@type boolean Notify about possible problems or not
      notify = true,
      ---@type boolean Use `dot` for repeat action
      dot_repeat = true,
      ---@type nil|function Callback for treesj error handler. func (err_text, level, ...other_text)
      on_error = nil,
      ---@type table Presets for languages
      -- langs = {}, -- See the default presets in lua/treesj/langs
    }

    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    map('n', '<leader>ct', '<cmd>lua require("treesj").toggle()<cr>', { desc = '[C]ode [t]oggle', noremap = opts.noremap, silent = opts.silent })
    map('n', '<leader>cj', '<cmd>lua require("treesj").join()<cr>', { desc = '[C]ode [j]oin', noremap = opts.noremap, silent = opts.silent })
    map('n', '<leader>cs', '<cmd>lua require("treesj").split()<cr>', { desc = '[C]ode [s]plit', noremap = opts.noremap, silent = opts.silent })
  end,
}
