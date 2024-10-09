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
    }
  end,
}
