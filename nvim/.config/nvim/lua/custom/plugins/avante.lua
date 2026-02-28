return {
  'yetone/avante.nvim',
  version = false, -- set this if you want to always pull the latest change
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  -- Using prebuilt binaries since Rust/Cargo is not installed
  build = 'make BUILD_FROM_SOURCE=false',
  -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  dependencies = {
    'nvim-lua/plenary.nvim',
    'MunifTanjim/nui.nvim',
    --- The below dependencies are optional,
    'nvim-tree/nvim-web-devicons', -- or echasnovski/mini.icons
    'zbirenbaum/copilot.lua', -- for providers='copilot'
    {
      -- support for image pasting
      'HakonHarnes/img-clip.nvim',
      event = 'VeryLazy',
      opts = {
        -- recommended settings
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          -- required for Windows users
          use_absolute_path = true,
        },
      },
    },
  },

  config = function()
    require('avante').setup {
      -- add any opts here
      debug = false,
      ---@alias avante.Mode "agentic" | "legacy"
      ---@type avante.Mode
      mode = 'agentic',
      ---@alias avante.ProviderName "claude" | "openai" | "azure" | "gemini" | "vertex" | "cohere" | "copilot" | "bedrock" | "ollama" | "watsonx_code_assistant" | string
      ---@type avante.ProviderName
      provider = 'copilot', -- recommend using Claude for better code understanding
      -- WARNING: Since auto-suggestions are a high-frequency operation and therefore expensive,
      -- currently designating it as `copilot` provider is dangerous because: https://github.com/yetone/avante.nvim/issues/1048
      -- Of course, you can reduce the request frequency by increasing `suggestion.debounce`.
      providers = {
        copilot = {
          endpoint = 'https://api.githubcopilot.com',
          model = 'claude-sonnet-4.5', -- prefer using Claude 4.5 'claude-sonnet-4.5' (but incurs a premium multiplier of 1)
          proxy = nil, -- [protocol://]host[:port] Use this proxy
          allow_insecure = false, -- Allow insecure server connections
          timeout = 30000, -- Timeout in milliseconds
          extra_request_body = {
            temperature = 0,
            max_tokens = 4096,
          },
        },
      },
      behaviour = {
        auto_suggestions = false, -- Disabled to ensure user prompting
        auto_set_highlight_group = true,
        auto_set_keymaps = true,
        auto_apply_diff_after_generation = false, -- Disabled to require manual approval
        auto_approve_tool_permissions = false,
        support_paste_from_clipboard = true,
      },
      mappings = {
        --- @class AvanteConflictMappings
        diff = {
          ours = 'co',
          theirs = 'ct',
          all_theirs = 'ca',
          both = 'cb',
          cursor = 'cc',
          next = ']x',
          prev = '[x',
        },
        suggestion = {
          accept = '<M-l>',
          next = '<M-]>',
          prev = '<M-[>',
          dismiss = '<C-]>',
        },
        jump = {
          next = ']]',
          prev = '[[',
        },
        submit = {
          normal = '<CR>',
          insert = '<C-s>',
        },
        sidebar = {
          apply_all = 'A',
          apply_cursor = 'a',
          switch_windows = '<Tab>',
          reverse_switch_windows = '<S-Tab>',
        },
      },
      hints = { enabled = true },
      windows = {
        ---@type "right" | "left" | "top" | "bottom"
        position = 'right', -- the position of the sidebar
        wrap = true, -- similar to vim.o.wrap
        width = 40, -- default % based on available width
        sidebar_header = {
          align = 'center', -- left, center, right for title
          rounded = false,
        },
      },
      selector = {
        --- @alias avante.SelectorProvider "native" | "fzf_lua" | "mini_pick" | "snacks" | "telescope" | fun(selector: avante.ui.Selector): nil
        --- @type avante.SelectorProvider
        provider = 'snacks',
        -- Options override for custom providers
        provider_opts = {},
      },
      input = {
        provider = 'snacks',
        provider_opts = {
          -- Additional snacks.input options
          title = 'Avante Input',
          icon = ' ',
        },
      },
      highlights = {
        ---@type AvanteConflictHighlights
        diff = {
          current = 'DiffText',
          incoming = 'DiffAdd',
        },
      },
      --- @class AvanteConflictUserConfig
      diff = {
        autojump = true,
        ---@type string | fun(): string
        list_opener = 'copen',
      },
      disabled_tools = {
        'list_files', -- Built-in file operations
        'search_files',
        'read_file',
        'create_file',
        'rename_file',
        'delete_file',
        'create_dir',
        'rename_dir',
        'delete_dir',
        'bash', -- Built-in terminal access
      },
      -- system_prompt as function ensures LLM always has latest MCP server state
      -- This is evaluated for every message, even in existing chats
      system_prompt = function()
        local hub = require('mcphub').get_hub_instance()
        return hub and hub:get_active_servers_prompt() or ''
      end,
      -- Using function prevents requiring mcphub before it's loaded
      custom_tools = function()
        return {
          require('mcphub.extensions.avante').mcp_tool(),
        }
      end,
    }
  end,
}
