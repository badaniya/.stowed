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
      -- The coverage file paths neeed to be converted from github paths to
      -- local replacement paths.
      if ftype == 'go' then
        local config = require 'coverage.config'
        local project_dir = 'GoDCApp/NVO'
        local coverage_mode = 'mode:'
        local is_modified = false
        local fileContent = {}

        vim.notify('Loading coverage file ' .. config.opts.lang.go.coverage_file .. ' ...')
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
        end
      end

      -- notify that the coverage file has been loaded
      vim.notify('Loaded ' .. ftype .. ' coverage')
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

  vim.keymap.set('n', '<leader>cc', ':Coverage<CR>', { desc = '[C]ode [C]overage' }),
  vim.keymap.set('n', '<leader>cs', ':CoverageSummary<CR>', { desc = '[C]ode [S]ummary' }),
  vim.keymap.set('n', '<leader>ce', ':CoverageClear<CR>', { desc = '[C]ode Cl[e]ar' }),
}
