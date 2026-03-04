return {
  'olimorris/codecompanion.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'ravitemer/mcphub.nvim',
    'ravitemer/codecompanion-history.nvim',
    'lalitmee/codecompanion-spinners.nvim', -- Add the spinners extension
  },

  config = function()
    require('codecompanion').setup {
      -- your configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
      opts = {
        render_modes = true, -- Render in ALL modes
        sign = {
          enabled = false, -- Turn off in the status column
        },
      },
      display = {
        chat = {
          window = {
            layout = 'vertical', -- float|vertical|horizontal|buffer
            position = nil, -- left|right|top|bottom (nil will default depending on vim.opt.splitright|vim.opt.splitbelow)
            border = 'single',
            height = 0.8,
            width = 0.40,
            relative = 'editor',
            full_height = true, -- when set to false, vsplit will be used to open the chat buffer vs. botright/topleft vsplit
            sticky = false, -- when set to true and `layout` is not `"buffer"`, the chat buffer will remain opened when switching tabs
            opts = {
              breakindent = true,
              cursorcolumn = false,
              cursorline = false,
              foldcolumn = '0',
              linebreak = true,
              list = false,
              numberwidth = 1,
              signcolumn = 'no',
              spell = false,
              wrap = true,
            },
          },
        },
      },
      strategies = {
        chat = {
          display = {
            intro_message = 'Welcome to CodeCompanion ✨! Press ? for options',
            separator = '─', -- The separator between the different messages in the chat buffer
            show_context = true, -- Show context (from slash commands and variables) in the chat buffer?
            show_header_separator = false, -- Show header separators in the chat buffer? Set this to false if you're using an external markdown formatting plugin
            show_settings = true, -- Show LLM settings at the top of the chat buffer?
            show_token_count = true, -- Show the token count for each response?
            show_tools_processing = true, -- Show the loading message when tools are being executed?
            start_in_insert_mode = false, -- Open the chat buffer in insert mode?
          },
          adapter = {
            name = 'copilot',
            model = 'claude-sonnet-4.5', -- prefer using Claude 4.5 'claude-sonnet-4.5' (but incurs a premium multiplier of 1)
          },
          roles = {
            ---The header name for the LLM's messages
            ---@type string|fun(adapter: CodeCompanion.HTTPAdapter|CodeCompanion.ACPAdapter): string
            llm = function(adapter)
              return ' CodeCompanion (' .. adapter.formatted_name .. ')'
            end,

            ---The header name for your messages
            ---@type string
            user = ' User (' .. vim.env.USER .. ')',
          },
          tools = {
            opts = {
              auto_submit_errors = true, -- Send any errors to the LLM automatically?
              auto_submit_success = true, -- Send any successful output to the LLM automatically?
              folds = {
                enabled = false, -- Fold tool output in the buffer?
                failure_words = { -- Words that indicate an error in the tool output. Used to apply failure highlighting
                  'cancelled',
                  'error',
                  'failed',
                  'incorrect',
                  'invalid',
                  'rejected',
                },
              },
            },
          },
          opts = {
            ---Decorate the user message before it's sent to the LLM
            ---@param message string
            ---@param adapter CodeCompanion.Adapter
            ---@param context table
            ---@return string
            prompt_decorator = function(message, adapter, context)
              return string.format([[<prompt>%s</prompt>]], message)
            end,
          },
        },
        inline = {
          adapter = {
            name = 'copilot',
            model = 'claude-sonnet-4.5', -- prefer using Claude 4.5 'claude-sonnet-4.5' (but incurs a premium multiplier of 1)
          },
        },
      },
      extensions = {
        -- 🌀 Add the spinners extension
        spinner = {
          enabled = true,
          opts = {
            -- Choose your preferred spinner style:
            -- "cursor-relative" - Floating window near cursor (default)
            -- "fidget" - Uses fidget.nvim for progress notifications
            -- "snacks" - Rich notifications via snacks.nvim
            -- "lualine" - Statusline integration for lualine users
            -- "heirline" - Statusline integration for heirline users
            -- "native" - Configurable floating window
            -- "none" - Disable all spinners
            style = 'snacks', -- Using snacks since you have it configured

            -- You can also try "fidget" since you have fidget.nvim installed:
            -- style = "fidget",

            -- Custom content for different states (optional - these are the defaults)
            content = {
              -- 🧠 General states
              thinking = { icon = ' ', message = 'Thinking...', spacing = ' ' },
              receiving = { icon = ' ', message = 'Receiving...', spacing = ' ' },
              done = { icon = '✅', message = 'Done!', spacing = ' ' },
              stopped = { icon = '🛑', message = 'Stopped', spacing = ' ' },
              cleared = { icon = '🧹', message = 'Chat cleared', spacing = ' ' },

              -- 🔧 Tool-related states
              tools_started = { icon = '🔧', message = 'Running tools...', spacing = ' ' },
              tools_finished = { icon = '⚙️', message = 'Processing tool output...', spacing = ' ' },

              -- 📝 Diff-related states
              diff_attached = { icon = '📝', message = 'Review changes', spacing = ' ' },
              diff_accepted = { icon = '✅', message = 'Change accepted', spacing = ' ' },
              diff_rejected = { icon = '❌', message = 'Change rejected', spacing = ' ' },

              -- 💬 Chat-related states
              chat_ready = { icon = '💬', message = 'Chat ready', spacing = ' ' },
              chat_opened = { icon = '💭', message = 'Chat opened', spacing = ' ' },
              chat_hidden = { icon = '👁', message = 'Chat hidden', spacing = ' ' },
              chat_closed = { icon = '🚪', message = 'Chat closed', spacing = ' ' },
            },
          },
        },
        history = {
          enabled = true,
          opts = {
            -- Keymap to open history from chat buffer (default: gh)
            keymap = 'gh',
            -- Keymap to save the current chat manually (when auto_save is disabled)
            save_chat_keymap = 'sc',
            -- Save all chats by default (disable to save only manually using 'sc')
            auto_save = true,
            -- Number of days after which chats are automatically deleted (0 to disable)
            expiration_days = 0,
            -- Picker interface (auto resolved to a valid picker)
            picker = 'snacks', --- ("telescope", "snacks", "fzf-lua", or "default")
            ---Optional filter function to control which chats are shown when browsing
            chat_filter = nil, -- function(chat_data) return boolean end
            -- Customize picker keymaps (optional)
            picker_keymaps = {
              rename = { n = 'r', i = '<M-r>' },
              delete = { n = 'd', i = '<M-d>' },
              duplicate = { n = '<C-y>', i = '<C-y>' },
            },
            ---Automatically generate titles for new chats
            auto_generate_title = true,
            title_generation_opts = {
              ---Adapter for generating titles (defaults to current chat adapter)
              adapter = nil, -- "copilot"
              ---Model for generating titles (defaults to current chat model)
              model = nil, -- "gpt-4o"
              ---Number of user prompts after which to refresh the title (0 to disable)
              refresh_every_n_prompts = 0, -- e.g., 3 to refresh after every 3rd user prompt
              ---Maximum number of times to refresh the title (default: 3)
              max_refreshes = 3,
              format_title = function(original_title)
                -- this can be a custom function that applies some custom
                -- formatting to the title.
                return original_title
              end,
            },
            ---On exiting and entering neovim, loads the last chat on opening chat
            continue_last_chat = false,
            ---When chat is cleared with `gx` delete the chat from history
            delete_on_clearing_chat = false,
            ---Directory path to save the chats
            dir_to_save = vim.fn.stdpath 'data' .. '/codecompanion-history',
            ---Enable detailed logging for history extension
            enable_logging = false,

            -- Summary system
            summary = {
              -- Keymap to generate summary for current chat (default: "gcs")
              create_summary_keymap = 'gcs',
              -- Keymap to browse summaries (default: "gbs")
              browse_summaries_keymap = 'gbs',

              generation_opts = {
                adapter = nil, -- defaults to current chat adapter
                model = nil, -- defaults to current chat model
                context_size = 90000, -- max tokens that the model supports
                include_references = true, -- include slash command content
                include_tool_outputs = true, -- include tool execution results
                system_prompt = nil, -- custom system prompt (string or function)
                format_summary = nil, -- custom function to format generated summary e.g to remove <think/> tags from summary
              },
            },

            -- Memory system (requires VectorCode CLI)
            memory = {
              -- Automatically index summaries when they are generated
              auto_create_memories_on_summary_generation = true,
              -- Path to the VectorCode executable
              vectorcode_exe = 'vectorcode',
              -- Tool configuration
              tool_opts = {
                -- Default number of memories to retrieve
                default_num = 10,
              },
              -- Enable notifications for indexing progress
              notify = true,
              -- Index all existing memories on startup
              -- (requires VectorCode 0.6.12+ for efficient incremental indexing)
              index_on_startup = false,
            },
          },
        },
        vectorcode = {
          ---@type VectorCode.CodeCompanion.ExtensionOpts
          opts = {
            tool_group = {
              -- this will register a tool group called `@vectorcode_toolbox` that contains all 3 tools
              enabled = true,
              -- a list of extra tools that you want to include in `@vectorcode_toolbox`.
              -- if you use @vectorcode_vectorise, it'll be very handy to include
              -- `file_search` here.
              extras = {},
              collapse = false, -- whether the individual tools should be shown in the chat
            },
            tool_opts = {
              ---@type VectorCode.CodeCompanion.ToolOpts
              ['*'] = {},
              ---@type VectorCode.CodeCompanion.LsToolOpts
              ls = {},
              ---@type VectorCode.CodeCompanion.VectoriseToolOpts
              vectorise = {},
              ---@type VectorCode.CodeCompanion.QueryToolOpts
              query = {
                max_num = { chunk = -1, document = -1 },
                default_num = { chunk = 50, document = 10 },
                include_stderr = false,
                use_lsp = false,
                no_duplicate = true,
                chunk_mode = false,
                ---@type VectorCode.CodeCompanion.SummariseOpts
                summarise = {
                  ---@type boolean|(fun(chat: CodeCompanion.Chat, results: VectorCode.QueryResult[]):boolean)|nil
                  enabled = false,
                  adapter = nil,
                  query_augmented = true,
                },
              },
              files_ls = {},
              files_rm = {},
            },
          },
        },
        mcphub = {
          callback = 'mcphub.extensions.codecompanion',
          opts = {
            make_vars = true,
            make_slash_commands = true,
            show_results_in_chat = true,
          },
        },
      },
    }
    local map = vim.keymap.set
    local opts = { noremap = true, silent = true }

    -- Move to previous/next
    map({ 'n', 'v' }, '<LocalLeader>Ca', '<cmd>CodeCompanionActions<cr>', { desc = 'Code[C]ompanion [A]ctions', noremap = opts.noremap, silent = opts.silent })
    map({ 'n', 'v' }, '<LocalLeader>Cc', '<cmd>CodeCompanionChat Toggle<cr>', { desc = 'Code[C]ompanion [C]hat', noremap = opts.noremap, silent = opts.silent })
    map('v', 'ga', '<cmd>CodeCompanionChat Add<cr>', opts)

    -- Expand 'cc' into 'CodeCompanion' in the command line
    vim.cmd [[cab cc CodeCompanion]]
  end,
}
