return {
  'mfussenegger/nvim-lint',

  config = function()
    local lint = require 'lint'
    lint.linters_by_ft = {
      go = {
        'golangcilint',
      },
      nix = { 'nix' },
      lua = { 'luacheck' },
    }

    vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufWritePost' }, {
      callback = function()
        -- try_lint without arguments runs the linters defined in `linters_by_ft`
        -- for the current filetype
        if not (lint == nil) then
          if vim.bo.buftype == '' then
            lint.try_lint()
          end
        end
      end,
    })
  end,
}
