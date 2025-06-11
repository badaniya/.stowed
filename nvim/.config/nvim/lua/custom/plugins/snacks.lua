return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    -- your configuration comes here
    -- or leave it empty to use the default settings
    -- refer to the configuration section below

    bigfile = { enabled = true },

    dashboard = {
      enabled = true,
      ---@class snacks.dashboard.Config
      ---@field enabled? boolean
      ---@field sections snacks.dashboard.Section
      ---@field formats table<string, snacks.dashboard.Text|fun(item:snacks.dashboard.Item, ctx:snacks.dashboard.Format.ctx):snacks.dashboard.Text>
      width = 60,
      row = nil, -- dashboard position. nil for center
      col = nil, -- dashboard position. nil for center
      pane_gap = 4, -- empty columns between vertical panes
      autokeys = '1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', -- autokey sequence
      -- These settings are used by some built-in sections
      preset = {
        -- Defaults to a picker that supports `fzf-lua`, `telescope.nvim` and `mini.pick`
        ---@type fun(cmd:string, opts:table)|nil
        pick = nil,
        -- Used by the `keys` section to show keymaps.
        -- Set your custom keymaps here.
        -- When using a function, the `items` argument are the default keymaps.
        ---@type snacks.dashboard.Item[]
        keys = {
          { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
          { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
          { icon = ' ', key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = ' ', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = ' ', key = 'c', desc = 'Config', action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
          { icon = ' ', key = 's', desc = 'Restore Session', section = 'session' },
          { icon = '󰒲 ', key = 'L', desc = 'Lazy', action = ':Lazy', enabled = package.loaded.lazy ~= nil },
          { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
        },
        -- Used by the `header` section
        header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
      },
      -- item field formatters
      formats = {
        icon = function(item)
          if item.file and item.icon == 'file' or item.icon == 'directory' then
            return M.icon(item.file, item.icon)
          end
          return { item.icon, width = 2, hl = 'icon' }
        end,
        footer = { '%s', align = 'center' },
        header = { '%s', align = 'center' },
        file = function(item, ctx)
          local fname = vim.fn.fnamemodify(item.file, ':~')
          fname = ctx.width and #fname > ctx.width and vim.fn.pathshorten(fname) or fname
          if #fname > ctx.width then
            local dir = vim.fn.fnamemodify(fname, ':h')
            local file = vim.fn.fnamemodify(fname, ':t')
            if dir and file then
              file = file:sub(-(ctx.width - #dir - 2))
              fname = dir .. '/…' .. file
            end
          end
          local dir, file = fname:match '^(.*)/(.+)$'
          return dir and { { dir .. '/', hl = 'dir' }, { file, hl = 'file' } } or { { fname, hl = 'file' } }
        end,
      },
      sections = {
        { section = 'header' },
        { section = 'keys', gap = 1 },
        { section = 'startup' },
      },
    },

    explorer = { enabled = true },

    indent = {
      enabled = true,
      ---@class snacks.indent.Config
      ---@field enabled? boolean
      indent = {
        priority = 1,
        enabled = true, -- enable indent guides
        char = '│',
        only_scope = false, -- only show indent guides of the scope
        only_current = false, -- only show indent guides in the current window
        hl = 'SnacksIndent', ---@type string|string[] hl groups for indent guides
        -- can be a list of hl groups to cycle through
        -- hl = {
        --     "SnacksIndent1",
        --     "SnacksIndent2",
        --     "SnacksIndent3",
        --     "SnacksIndent4",
        --     "SnacksIndent5",
        --     "SnacksIndent6",
        --     "SnacksIndent7",
        --     "SnacksIndent8",
        -- },
      },
      animate = {
        enabled = vim.fn.has 'nvim-0.10' == 1,
        -- animate scopes. Enabled by default for Neovim >= 0.10
        -- Works on older versions but has to trigger redraws during animation.
        ---@class snacks.indent.animate: snacks.animate.Config
        ---@field enabled? boolean
        --- * out: animate outwards from the cursor
        --- * up: animate upwards from the cursor
        --- * down: animate downwards from the cursor
        --- * up_down: animate up or down based on the cursor position
        ---@field style? "out"|"up_down"|"down"|"up"
        style = 'out',
        easing = 'linear',
        duration = {
          step = 10, -- ms per step
          total = 500, -- maximum duration
        },
      },
      ---@class snacks.indent.Scope.Config: snacks.scope.Config
      scope = {
        enabled = true, -- enable highlighting the current scope
        priority = 200,
        char = '│',
        underline = false, -- underline the start of the scope
        only_current = false, -- only show scope in the current window
        hl = 'SnacksIndentScope', ---@type string|string[] hl group for scopes
      },
      chunk = {
        -- when enabled, scopes will be rendered as chunks, except for the
        -- top-level scope which will be rendered as a scope.
        enabled = false,
        -- only show chunk scopes in the current window
        only_current = false,
        priority = 200,
        hl = 'SnacksIndentChunk', ---@type string|string[] hl group for chunk scopes
        char = {
          corner_top = '┌',
          corner_bottom = '└',
          -- corner_top = "╭",
          -- corner_bottom = "╰",
          horizontal = '─',
          vertical = '│',
          arrow = '>',
        },
      },
      -- filter for buffers to enable indent guides
      filter = function(buf)
        return vim.g.snacks_indent ~= false and vim.b[buf].snacks_indent ~= false and vim.bo[buf].buftype == ''
      end,
    },

    image = {
      enabled = true,
      ---@class snacks.image.Config
      ---@field enabled? boolean enable image viewer
      ---@field wo? vim.wo|{} options for windows showing the image
      ---@field bo? vim.bo|{} options for the image buffer
      ---@field formats? string[]
      --- Resolves a reference to an image with src in a file (currently markdown only).
      --- Return the absolute path or url to the image.
      --- When `nil`, the path is resolved relative to the file.
      ---@field resolve? fun(file: string, src: string): string?
      ---@field convert? snacks.image.convert.Config
      formats = {
        'png',
        'jpg',
        'jpeg',
        'gif',
        'bmp',
        'webp',
        'tiff',
        'heic',
        'avif',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
        'pdf',
      },
      force = false, -- try displaying the image, even if the terminal does not support it
      doc = {
        -- enable image viewer for documents
        -- a treesitter parser must be available for the enabled languages.
        enabled = true,
        -- render the image inline in the buffer
        -- if your env doesn't support unicode placeholders, this will be disabled
        -- takes precedence over `opts.float` on supported terminals
        inline = false,
        -- render the image in a floating window
        -- only used if `opts.inline` is disabled
        float = true,
        max_width = 80,
        max_height = 40,
        -- Set to `true`, to conceal the image text when rendering inline.
        -- (experimental)
        ---@param lang string tree-sitter language
        ---@param type snacks.image.Type image type
        conceal = function(lang, type)
          -- only conceal math expressions
          return type == 'math'
        end,
      },
      img_dirs = { 'img', 'images', 'assets', 'static', 'public', 'media', 'attachments' },
      -- window options applied to windows displaying image buffers
      -- an image buffer is a buffer with `filetype=image`
      wo = {
        wrap = false,
        number = false,
        relativenumber = false,
        cursorcolumn = false,
        signcolumn = 'no',
        foldcolumn = '0',
        list = false,
        spell = false,
        statuscolumn = '',
      },
      cache = vim.fn.stdpath 'cache' .. '/snacks/image',
      debug = {
        request = false,
        convert = false,
        placement = false,
      },
      env = {},
      -- icons used to show where an inline image is located that is
      -- rendered below the text.
      icons = {
        math = '󰪚 ',
        chart = '󰄧 ',
        image = ' ',
      },
      ---@class snacks.image.convert.Config
      convert = {
        notify = true, -- show a notification on error
        ---@type snacks.image.args
        mermaid = function()
          local theme = vim.o.background == 'light' and 'neutral' or 'dark'
          return { '-i', '{src}', '-o', '{file}', '-b', 'transparent', '-t', theme, '-s', '{scale}' }
        end,
        ---@type table<string,snacks.image.args>
        magick = {
          default = { '{src}[0]', '-scale', '1920x1080>' }, -- default for raster images
          vector = { '-density', 192, '{src}[0]' }, -- used by vector images like svg
          math = { '-density', 192, '{src}[0]', '-trim' },
          pdf = { '-density', 192, '{src}[0]', '-background', 'white', '-alpha', 'remove', '-trim' },
        },
      },
      math = {
        enabled = true, -- enable math expression rendering
        -- in the templates below, `${header}` comes from any section in your document,
        -- between a start/end header comment. Comment syntax is language-specific.
        -- * start comment: `// snacks: header start`
        -- * end comment:   `// snacks: header end`
        typst = {
          tpl = [[
        #set page(width: auto, height: auto, margin: (x: 2pt, y: 2pt))
        #show math.equation.where(block: false): set text(top-edge: "bounds", bottom-edge: "bounds")
        #set text(size: 12pt, fill: rgb("${color}"))
        ${header}
        ${content}]],
        },
        latex = {
          font_size = 'Large', -- see https://www.sascha-frank.com/latex-font-size.html
          -- for latex documents, the doc packages are included automatically,
          -- but you can add more packages here. Useful for markdown documents.
          packages = { 'amsmath', 'amssymb', 'amsfonts', 'amscd', 'mathtools' },
          tpl = [[
        \documentclass[preview,border=0pt,varwidth,12pt]{standalone}
        \usepackage{${packages}}
        \begin{document}
        ${header}
        { \${font_size} \selectfont
          \color[HTML]{${color}}
        ${content}}
        \end{document}]],
        },
      },
    },

    input = {
      enabled = true,
      ---@class snacks.input.Config
      ---@field enabled? boolean
      ---@field win? snacks.win.Config|{}
      ---@field icon? string
      ---@field icon_pos? snacks.input.Pos
      ---@field prompt_pos? snacks.input.Pos
      icon = ' ',
      icon_hl = 'SnacksInputIcon',
      icon_pos = 'left',
      prompt_pos = 'title',
      win = { style = 'input' },
      expand = true,
    },

    picker = { enabled = true },

    notifier = { enabled = true },

    quickfile = { enabled = true },

    scope = { enabled = true },

    scroll = { enabled = false },

    statuscolumn = { enabled = false },

    words = { enabled = true },
  },
}
