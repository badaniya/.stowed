return {
  { -- Numberless Fold Status Column
    'luukvbaal/statuscol.nvim',
    opts = function()
      local builtin = require 'statuscol.builtin'
      return {
        setopt = true,
        -- override the default list of segments with:
        -- number-less fold indicator, then signs, then line number & separator
        segments = {
          { text = { builtin.foldfunc }, click = 'v:lua.ScFa' },
          { text = { '%s' }, click = 'v:lua.ScSa' },
          {
            text = { builtin.lnumfunc, ' ' },
            condition = { true, builtin.not_empty },
            click = 'v:lua.ScLa',
          },
        },
      }
    end,
  },
  { -- Enhanced Folding
    'chrisgrieser/nvim-origami',
    event = 'VeryLazy',
    opts = {}, -- needed even when using default config

    -- recommended: disable vim's auto-folding
    init = function()
      vim.opt.foldcolumn = '1' -- Add this line to show fold indicators
      vim.opt.foldlevel = 99
      vim.opt.foldlevelstart = 99
      vim.opt.fillchars = [[eob: ,fold: ,foldopen:󰧖,foldsep:│,foldclose:󰧚]]
    end,

    config = function(_, opts)
      -- default settings
      require('origami').setup {
        useLspFoldsWithTreesitterFallback = true, -- required for `autoFold`
        autoFold = {
          enabled = true,
          kinds = { 'comment', 'imports' }, ---@type lsp.FoldingRangeKind[]
        },
        foldtext = {
          enabled = true,
          lineCount = {
            template = '  󰘖  %d   …', -- `%d` is repalced with the number of folded lines
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
  },
}
