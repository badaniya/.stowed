-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',
    dependencies = {
      -- Required dependency for nvim-dap-ui
      'nvim-neotest/nvim-nio',
    },

    -- Installs the debug adapters for you
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add inline debug virtual-text
    'theHamsta/nvim-dap-virtual-text',

    -- Add your own debuggers here
    'leoluz/nvim-dap-go',
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'
    local dap_go = require 'dap-go'
    local mason_nvim_dap = require 'mason-nvim-dap'
    local nvim_dap_virtual_text = require 'nvim-dap-virtual-text'

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
      --controls = {
      --  icons = {
      --    pause = '⏸',
      --    play = '▶',
      --    step_into = '⏎',
      --    step_over = '⏭',
      --    step_out = '⏮',
      --    step_back = 'b',
      --    run_last = '▶▶',
      --    terminate = '⏹',
      --    disconnect = '⏏',
      --  },
      --},
    }

    -- Dap listeners
    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Install golang specific config
    dap_go.setup {
      delve = {
        -- On Windows delve must be run attached or it crashes.
        -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
        detached = vim.fn.has 'win32' == 0,
        args = {},
        build_flags = '-tags=ci_jenkins',
        cwd = nil,
      },
    }

    mason_nvim_dap.setup {
      -- Makes a best effort to setup the various debuggers with
      -- reasonable debug configurations
      automatic_installation = true,

      -- You'll need to check that you have the required things installed
      -- online, please don't ask me how to install them :)
      ensure_installed = {
        -- Update this to ensure that you have the debuggers for the langs you want
        'delve',
      },

      -- You can provide additional configuration to the handlers,
      -- see mason-nvim-dap README for more information
      handlers = nil,
    }

    nvim_dap_virtual_text.setup {}

    -- Basic debugging keymaps, feel free to change to your liking!
    vim.keymap.set('n', '<F2>', dap.step_into, { desc = 'Debug: Step Into' })
    vim.keymap.set('n', '<F3>', dap.step_over, { desc = 'Debug: Step Over' })
    vim.keymap.set('n', '<F4>', dap.step_out, { desc = 'Debug: Step Out' })
    vim.keymap.set('n', '<F5>', dap.continue, { desc = 'Debug: Start/Continue' })
    -- For Debugging a test!
    vim.keymap.set('n', '<F6>', function()
      dap_go.debug_test()
    end, { desc = 'Debug: Nearest Test' })
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    vim.keymap.set('n', '<F7>', dapui.toggle, { desc = 'Debug: See last session result.' })
    vim.keymap.set('n', '<F8>', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
    vim.keymap.set('n', '<F9>', function()
      dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
    end, { desc = 'Debug: Set Breakpoint' })
    vim.keymap.set('n', '<F12>', dap.disconnect, { desc = 'Debug: Disconnect' })
    vim.keymap.set('n', '<M-k>', '<Cmd>lua require("dapui").eval()<CR>', { desc = 'Debug: Eval at cursor' })

    -- Pretty up the debug breakpoints
    vim.fn.sign_define('DapBreakpoint', { text = '🔴', texthl = '', linehl = '', numhl = 'DapBreakpoint' })
    vim.fn.sign_define('DapBreakpointCondition', { text = '🟡', texthl = '', linehl = '', numhl = 'DapBreakpointCondition' })
    vim.fn.sign_define('DapStopped', { text = '', texthl = '', linehl = '', numhl = 'DapStopped' })
  end,
}
