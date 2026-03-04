return {
  'mawkler/demicolon.nvim',
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-treesitter/nvim-treesitter-textobjects',
  },
  opts = {},

  config = function()
    require('demicolon').setup {
      keymaps = {
        -- Create t/T/f/F key mappings
        horizontal_motions = false,
        -- Create ; and , key mappings. Set it to 'stateless', 'stateful', or false to
        -- not create any mappings. 'stateless' means that ;/, move right/left.
        -- 'stateful' means that ;/, will remember the direction of the original
        -- jump, and `,` inverts that direction (Neovim's default behaviour).
        repeat_motions = 'stateful',
        -- Keys that shouldn't be repeatable (because aren't motions), excluding the prefix `]`/`[`
        -- If you have custom motions that use one of these, make sure to remove that key from here
        disabled_keys = { 'p', 'I', 'A', 'f', 'i' },
      },
    }

    local flash_char = require 'flash.plugins.char'
    ---@param options { key: string, fowrard: boolean }
    local function flash_jump(options)
      return function()
        require('demicolon.jump').repeatably_do(function(o)
          local key = o.forward and o.key:lower() or o.key:upper()

          flash_char.jumping = true
          local autohide = require('flash.config').get('char').autohide

          -- Originally was
          -- if require("flash.repeat").is_repeat then
          if o.repeated then
            flash_char.jump_labels = false

            -- Originally was
            -- flash_char.state:jump({ count = vim.v.count1 })
            if o.forward then
              flash_char.right()
            else
              flash_char.left()
            end

            flash_char.state:show()
          else
            flash_char.jump(key)
          end

          vim.schedule(function()
            flash_char.jumping = false
            if flash_char.state and autohide then
              flash_char.state:hide()
            end
          end)
        end, options)
      end
    end

    vim.api.nvim_create_autocmd({ 'BufLeave', 'CursorMoved', 'InsertEnter' }, {
      group = vim.api.nvim_create_augroup('flash_char', { clear = true }),
      callback = function(event)
        local hide = event.event == 'InsertEnter' or not flash_char.jumping
        if hide and flash_char.state then
          flash_char.state:hide()
        end
      end,
    })

    vim.on_key(function(key)
      if flash_char.state and key == require('flash.util').ESC and (vim.fn.mode() == 'n' or vim.fn.mode() == 'v') then
        flash_char.state:hide()
      end
    end)

    vim.keymap.set({ 'n', 'x', 'o' }, 'f', flash_jump { key = 'f', forward = true }, { desc = 'Flash f' })
    vim.keymap.set({ 'n', 'x', 'o' }, 'F', flash_jump { key = 'F', forward = false }, { desc = 'Flash F' })
    vim.keymap.set({ 'n', 'x', 'o' }, 't', flash_jump { key = 't', forward = true }, { desc = 'Flash t' })
    vim.keymap.set({ 'n', 'x', 'o' }, 'T', flash_jump { key = 'T', forward = false }, { desc = 'Flash T' })
  end,
}
