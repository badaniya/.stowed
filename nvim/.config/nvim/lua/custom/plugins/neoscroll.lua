return {
  'karb94/neoscroll.nvim',
  config = function()
    local neoscroll = require 'neoscroll'
    neoscroll.setup {
      -- Default easing function used in any animation where
      -- the `easing` argument has not been explicitly supplied
      easing = 'sine',
    }

    local keymap = {
      -- When no value is passed the `easing` option supplied in `setup()` is used
      ['<C-u>'] = function()
        neoscroll.ctrl_u { duration = 150 }
      end,
      ['<C-d>'] = function()
        neoscroll.ctrl_d { duration = 150 }
      end,
      ['<C-b>'] = function()
        neoscroll.ctrl_b { duration = 250 }
      end,
      ['<C-f>'] = function()
        neoscroll.ctrl_f { duration = 250 }
      end,
      ['<C-y>'] = function()
        neoscroll.scroll(-0.1, { move_cursor = false, duration = 50 })
      end,
      ['<C-e>'] = function()
        neoscroll.scroll(0.1, { move_cursor = false, duration = 50 })
      end,
    }

    local modes = { 'n', 'v', 'x' }
    for key, func in pairs(keymap) do
      vim.keymap.set(modes, key, func)
    end
  end,
}