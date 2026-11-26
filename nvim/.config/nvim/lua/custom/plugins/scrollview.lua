return {
  'dstein64/nvim-scrollview',
  config = function()
    require('scrollview').setup {
      excluded_filetypes = { 'neo-tree' },
      current_only = true,
      -- It seems that custom specification does not work!
      -- signs_on_startup = { 'cursor', 'changelist', 'diagnostic', 'quickfix', 'marks', 'conflicts', 'latestchange' },
      signs_on_startup = { 'all' },
      diagnostics_severities = { vim.diagnostic.severity.WARN },
    }
  end,
}
