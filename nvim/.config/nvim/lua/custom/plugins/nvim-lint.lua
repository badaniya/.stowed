return {
  'mfussenegger/nvim-lint',

  config = function()
    local lint = require 'lint'
    lint.linters_by_ft = {
      bash = {
        'shellcheck',
        'shellharden',
      },
      dockerfile = {
        'hadolint',
      },
      go = {
        'gitleaks',
        'golangci-lint',
        'nilaway',
        'revive',
        'staticcheck',
        'trivy',
      },
      json = {
        'jsonlint',
      },
      markdown = {
        'markdownlint-cli2',
      },
      lua = {
        'luacheck',
        'stylua', -- Used to format Lua code
      },
    }

    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
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
