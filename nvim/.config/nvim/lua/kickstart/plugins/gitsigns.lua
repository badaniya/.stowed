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
        map('v', '<leader>ghs', function()
          gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[G]it [H]unk [S]tage' })
        map('v', '<leader>ghr', function()
          gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
        end, { desc = '[G]it [H]unk [R]eset' })
        -- normal mode
        map('n', '<leader>g', '', { desc = '[G]it' })
        map('n', '<leader>gh', '', { desc = '[G]it [H]unk' })
        map('n', '<leader>ghs', gitsigns.stage_hunk, { desc = '[G]it [H]unk [S]tage' })
        map('n', '<leader>ghu', gitsigns.undo_stage_hunk, { desc = '[G]it [H]unk Stage [U]ndo' })
        map('n', '<leader>ghr', gitsigns.reset_hunk, { desc = '[G]it [H]unk [R]eset' })
        map('n', '<leader>ghp', gitsigns.preview_hunk, { desc = '[G]it [H]unk [P]review' })
        map('n', '<leader>ga', gitsigns.stage_buffer, { desc = '[G]it [A]dd Stage Buffer' })
        map('n', '<leader>gr', gitsigns.reset_buffer, { desc = '[G]it [R]eset Stage Buffer' })
        -- map('n', '<leader>gb', gitsigns.blame_line, { desc = '[G]it [B]lame Line' })
        -- map('n', '<leader>gd', '', { desc = '[G]it [D]iff' })
        -- map('n', '<leader>gdi', gitsigns.diffthis, { desc = '[G]it [D]iff Against [I]ndex' })
        -- map('n', '<leader>gdc', function()
        --   gitsigns.diffthis '@'
        -- end, { desc = '[G]it [D]iff Against Last [C]ommit' })
        -- Toggles
        map('n', '<leader>gt', '', { desc = '[G]it [T]oggle' })
        map('n', '<leader>gtb', gitsigns.toggle_current_line_blame, { desc = '[G]it [T]oggle Show [B]lame Line' })
        map('n', '<leader>gtd', gitsigns.toggle_deleted, { desc = '[G]it [T]oggle Show [D]eleted' })
      end,
    },
  },
}
