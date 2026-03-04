return {
  'chrisgrieser/nvim-origami',
  event = 'VeryLazy',
  opts = {}, -- needed even when using default config

  -- recommended: disable vim's auto-folding
  init = function()
    vim.opt.foldlevel = 99
    vim.opt.foldlevelstart = 99
  end,

  config = function(_, opts)
    -- default settings
    require('origami').setup {
      useLspFoldsWithTreesitterFallback = {
        enabled = true, -- required for `autoFold`
        foldmethodIfNeitherIsAvailable = 'indent', ---@type string|fun(bufnr: number): string
      },
      autoFold = {
        enabled = true,
        kinds = { 'comment', 'imports' }, ---@type lsp.FoldingRangeKind[]
      },
      foldtext = {
        enabled = true,
        lineCount = {
          template = '…  󰐒%d', -- `%d` is repalced with the number of folded lines
          -- template = '…  󰘖 %d', -- `%d` is repalced with the number of folded lines
          -- template = '…  󰉸 %d', -- `%d` is repalced with the number of folded lines
          -- template = '…   %d', -- `%d` is repalced with the number of folded lines
          -- template = '…   %d', -- `%d` is repalced with the number of folded lines
          hlgroup = 'Comment',
        },
        diagnostics = {
          enabled = true,
          -- uses hlgroups and icons from `vim.diagnostic.config().signs`
        },
      },
      pauseFoldsOnSearch = true,
      foldKeymaps = {
        setup = true, -- modifies `h` and `l`
        hOnlyOpensOnFirstColumn = false,
      },
    }
  end,
}
