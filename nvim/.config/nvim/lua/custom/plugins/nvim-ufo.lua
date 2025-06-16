return {
  -- UFO folding
  {
    'kevinhwang91/nvim-ufo',
    dependencies = {
      'kevinhwang91/promise-async',
      {
        'luukvbaal/statuscol.nvim',
        config = function()
          local builtin = require 'statuscol.builtin'
          require('statuscol').setup {
            relculright = true,
            segments = {
              { text = { builtin.foldfunc }, click = 'v:lua.ScFa' },
              { text = { '%s' }, click = 'v:lua.ScSa' },
              { text = { builtin.lnumfunc, ' ' }, click = 'v:lua.ScLa' },
            },
          }
        end,
      },
    },
    event = 'BufReadPost',
    opts = {
      provider_selector = function()
        return { 'treesitter', 'indent' }
      end,
    },

    init = function()
      vim.o.foldcolumn = '1' -- '0' is not bad
      vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
      vim.o.fillchars = [[eob: ,fold: ,foldopen:󰧖,foldsep:│,foldclose:󰧚]]
      --vim.o.fillchars = [[eob: ,fold: ,foldopen:󰧖,foldsep:┊,foldclose:󰧚]]
      --vim.o.fillchars = [[eob: ,fold: ,foldopen:󰧖,foldsep:╎,foldclose:󰧚]]
    end,

    config = function(_, opts)
      local handler = function(virtText, lnum, endLnum, width, truncate)
        local newVirtText = {}
        local totalLines = vim.api.nvim_buf_line_count(0)
        local foldedLines = endLnum - lnum
        local suffix = (' 󰘕 %d %d%%'):format(foldedLines, foldedLines / totalLines * 100)
        local sufWidth = vim.fn.strdisplaywidth(suffix)
        local targetWidth = width - sufWidth
        local curWidth = 0
        for _, chunk in ipairs(virtText) do
          local chunkText = chunk[1]
          local chunkWidth = vim.fn.strdisplaywidth(chunkText)
          if targetWidth > curWidth + chunkWidth then
            table.insert(newVirtText, chunk)
          else
            chunkText = truncate(chunkText, targetWidth - curWidth)
            local hlGroup = chunk[2]
            table.insert(newVirtText, { chunkText, hlGroup })
            chunkWidth = vim.fn.strdisplaywidth(chunkText)
            -- str width returned from truncate() may less than 2nd argument, need padding
            if curWidth + chunkWidth < targetWidth then
              suffix = suffix .. (' '):rep(targetWidth - curWidth - chunkWidth)
            end
            break
          end
          curWidth = curWidth + chunkWidth
        end
        -- fold information inline
        local rAlignAppndx = math.max(math.min(vim.opt.textwidth['_value'], width - 1) - curWidth - sufWidth, 0)
        -- fold information on right-hand gutter
        --local rAlignAppndx = math.max(math.min(vim.api.nvim_win_get_width(0), width - 1) - curWidth - sufWidth, 0)
        suffix = (' '):rep(rAlignAppndx) .. suffix
        table.insert(newVirtText, { suffix, 'MoreMsg' })
        return newVirtText
      end
      opts['fold_virt_text_handler'] = handler
      require('ufo').setup(opts)
    end,
  },

  -- Folding session persistence
  {
    'chrisgrieser/nvim-origami',
    event = 'VeryLazy',
    opts = {}, -- needed even when using default config

    config = function(_, opts)
      -- default settings
      require('origami').setup {
        -- features incompatible with `nvim-ufo`
        useLspFoldsWithTreesitterFallback = not package.loaded['ufo'],
        autoFold = {
          enabled = false,
          kinds = { 'comment', 'imports' }, ---@type lsp.FoldingRangeKind[]
        },
        foldtextWithLineCount = {
          enabled = not package.loaded['ufo'],
          template = '   %s lines', -- `%s` gets the number of folded lines
          hlgroupForCount = 'Comment',
        },

        -- can be used with or without `nvim-ufo`
        pauseFoldsOnSearch = true,
        foldKeymaps = {
          setup = true, -- modifies `h` and `l`
          hOnlyOpensOnFirstColumn = false,
        },

        -- features requiring `nvim-ufo`
        keepFoldsAcrossSessions = package.loaded['ufo'],
      }
    end,
  },
}
