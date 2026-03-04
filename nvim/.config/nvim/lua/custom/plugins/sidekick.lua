return {
  'folke/sidekick.nvim',
  opts = {
    -- add any options here
    -- Work with AI cli tools directly from within Neovim
    cli = {
      watch = true, -- notify Neovim of file changes done by AI CLI tools
      ---@class sidekick.win.Opts
      win = {
        --- This is run when a new terminal is created, before starting it.
        --- Here you can change window options `terminal.opts`.
        ---@param terminal sidekick.cli.Terminal
        config = function(terminal) end,
        wo = {}, ---@type vim.wo
        bo = {}, ---@type vim.bo
        layout = 'right', ---@type "float"|"left"|"bottom"|"top"|"right"
        -- Options used when layout is "left"|"bottom"|"top"|"right"
        ---@type vim.api.keyset.win_config
        split = {
          width = 100, -- set to 0 for default split width
          height = 100, -- set to 0 for default split height
        },
      },
      mux = {
        backend = 'tmux',
        enabled = true,
        -- Options for tmux below do not seem to work.
        -- create = 'terminal', ---@type "terminal"|"window"|"split"
        -- split = {
        --   vertical = true, -- vertical or horizontal split
        --   size = 0.40, -- size of the split (0-1 for percentage)
        -- },
      },
      tools = {
        pi = {
          cmd = { 'pi' },
        },
        goose = {
          -- Start goose with zsh so the preexec hook is called.
          cmd = { 'goose', 'session' },
          -- Optional: custom keymaps for this tool
          -- keys = {
          --   submit = {
          --     '<c-s>',
          --     function(t)
          --       t:send '\n'
          --     end,
          --   },
          -- },
        },
      },
    },
  },
  -- stylua: ignore
  keys = {
    {
      "<tab>",
      function()
        -- if there is a next edit, jump to it, otherwise apply it if any
        if not require("sidekick").nes_jump_or_apply() then
          return "<Tab>" -- fallback to normal tab
        end
      end,
      expr = true,
      desc = "Goto/Apply Next Edit Suggestion",
    },
    {
      "<leader>Sa",
      function() require("sidekick.cli").toggle() end,
      desc = "Sidekick Toggle CLI",
    },
    {
      "<leader>Ss",
      function() require("sidekick.cli").select() end,
      -- Or to select only installed tools:
      -- require("sidekick.cli").select({ filter = { installed = true } })
      desc = "Select CLI",
    },
    {
      "<leader>St",
      function() require("sidekick.cli").send({ msg = "{this}" }) end,
      mode = { "x", "n" },
      desc = "Send This",
    },
    {
      "<leader>Sv",
      function() require("sidekick.cli").send({ msg = "{selection}" }) end,
      mode = { "x" },
      desc = "Send Visual Selection",
    },
    {
      "<leader>Sp",
      function() require("sidekick.cli").prompt() end,
      mode = { "n", "x" },
      desc = "Sidekick Select Prompt",
    },
    {
      "<c-.>",
      function() require("sidekick.cli").focus() end,
      mode = { "n", "x", "i", "t" },
      desc = "Sidekick Switch Focus",
    },
    -- Example of a keybinding to open Claude directly
    {
      "<leader>Sc",
      function() require("sidekick.cli").toggle({ name = "copilot", focus = true }) end,
      desc = "Sidekick Toggle Copilot",
    },
  },
}
