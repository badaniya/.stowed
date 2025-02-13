return {
  'andythigpen/nvim-coverage',
  ft = { 'go' },
  dependencies = {
    'nvim-lua/plenary.nvim',
  },
  opts = {
    auto_reload = true,
    lang = {
      go = {
        coverage_file = vim.fn.getcwd() .. '/coverage.out',
      },
    },
    commands = true, -- create commands
    load_coverage_cb = function(ftype)
      -- The `go` coverage.out file contain the prefixed github repo path
      -- but needs the relative replacement path to reference the local code.
      -- The coverage file paths need to be converted from github paths to
      -- local replacement paths.
      if ftype == 'go' then
        local config = require 'coverage.config'
        local project_dir = 'GoDCApp/NVO'
        local coverage_mode = 'mode:'
        local is_modified = false
        local fileContent = {}

        local file = io.open(config.opts.lang.go.coverage_file, 'r')

        if not (file == nil) then
          for line in file:lines() do
            if string.match(line, project_dir) then
              -- Match all GoDCApp/NVO paths
              local name = string.gsub(line, '.*' .. project_dir .. '(.*)', '%1')
              table.insert(fileContent, name)
              is_modified = true
            elseif string.match(line, '^' .. coverage_mode) then
              -- Match the coverage mode: <atomic | set | count>
              table.insert(fileContent, line)
            end
          end
          io.close(file)
        end

        if is_modified then
          file = io.open(config.opts.lang.go.coverage_file, 'w')

          if not (file == nil) then
            for _, value in ipairs(fileContent) do
              file:write(value .. '\n')
            end
            io.close(file)
          end
        else
          -- notify only when the file has been fully processed
          vim.notify('Loaded coverage file ' .. config.opts.lang.go.coverage_file)
        end
      else
        -- notify that the coverage file has been loaded
        vim.notify('Loaded ' .. ftype .. ' coverage')
      end
    end,
    highlights = {
      -- customize highlight groups created by the plugin
      covered = { fg = '#C3E88D' }, -- supports style, fg, bg, sp (see :h highlight-gui)
      uncovered = { fg = '#F07178' },
      partial = { fg = '#AA71F0' },
    },
    signs = {
      -- use your own highlight groups or text markers
      covered = { hl = 'CoverageCovered', text = '▎' },
      uncovered = { hl = 'CoverageUncovered', text = '▎' },
      partial = { hl = 'CoveragePartial', text = '▎' },
    },
    summary = {
      -- customize the summary pop-up
      min_coverage = 80.0, -- minimum coverage threshold (used for highlighting)
    },
  },

  config = function(_, opts)
    require('coverage').setup(opts)
  end,

  vim.keymap.set('n', '<leader>cc', '', { desc = '[C]ode [C]overage' }),
  vim.keymap.set('n', '<leader>cce', ':Coverage<CR>', { desc = '[C]ode [C]overage [E]nable' }),
  vim.keymap.set('n', '<leader>ccs', ':CoverageSummary<CR>', { desc = '[C]ode [C]overage [S]ummary' }),
  vim.keymap.set('n', '<leader>ccd', ':CoverageClear<CR>', { desc = '[C]ode [C]overage [D]isable' }),
}
