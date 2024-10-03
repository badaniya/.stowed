-- Adds git related signs to the gutter, as well as utilities for managing changes
-- NOTE: gitsigns is already included in init.lua but contains only the base
-- config. This will add also the recommended keymaps.

return {
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      on_attach = function(bufnr)
        local gitsigns = require 'gitsigns'

        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        -- Navigation
        map('n', ']c', function()
          if vim.wo.diff then
            vim.cmd.normal { ']c', bang = true }
          else
            gitsigns.nav_hunk 'next'
          end
        end, { desc = 'Jump to Next Git [C]hange' })

        map('n', '[c', function()
          if vim.wo.diff then
            vim.cmd.normal { '[c', bang = true }
          else
            gitsigns.nav_hunk 'prev'
          end
        end, { desc = 'Jump to Previous Git [C]hange' })

        -- Actions
        -- visual mode
        map('v', '<leader>hs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'Stage Git Hunk' })
        map('v', '<leader>hr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = 'Reset Git Hunk' })
        -- normal mode
        map('n', '<leader>h', '', { desc = 'Git [H]unk' })
        map('n', '<leader>hs', gitsigns.stage_hunk, { desc = 'Git [S]tage Hunk' })
        map('n', '<leader>hr', gitsigns.reset_hunk, { desc = 'Git [R]eset Hunk' })
        map('n', '<leader>hS', gitsigns.stage_buffer, { desc = 'Git [S]tage Buffer' })
        map('n', '<leader>hu', gitsigns.undo_stage_hunk, { desc = 'Git [U]ndo Stage Hunk' })
        map('n', '<leader>hR', gitsigns.reset_buffer, { desc = 'Git [R]eset Buffer' })
        map('n', '<leader>hp', gitsigns.preview_hunk, { desc = 'Git [P]review Hunk' })
        map('n', '<leader>hb', gitsigns.blame_line, { desc = 'Git [B]lame Line' })
        map('n', '<leader>hd', gitsigns.diffthis, { desc = 'Git [D]iff Against Index' })
        map('n', '<leader>hD', function()
          gitsigns.diffthis '@'
        end, { desc = 'Git [D]iff Against Last Commit' })
        -- Toggles
        map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = '[T]oggle Git Show [B]lame Line' })
        map('n', '<leader>tD', gitsigns.toggle_deleted, { desc = '[T]oggle Git Show [D]eleted' })
      end,
    },
  },
}
