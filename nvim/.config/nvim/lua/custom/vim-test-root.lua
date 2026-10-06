local M = {}

function M.resolve(path, filetype, fallback)
  if filetype ~= 'go' or path == '' then
    return fallback
  end

  local go_mod = vim.fs.find('go.mod', { path = vim.fs.dirname(path), upward = true })[1]
  return go_mod and vim.fs.dirname(go_mod) or fallback
end

function M.current_buffer_root()
  local buffer = vim.api.nvim_get_current_buf()
  return M.resolve(
    vim.api.nvim_buf_get_name(buffer),
    vim.bo[buffer].filetype,
    vim.fn.getcwd()
  )
end

function M.prefix_command(root, command)
  return ('cd %s && %s'):format(vim.fn.shellescape(root), command)
end

function M.command_for_dispatch(root, command, is_go)
  return is_go and M.prefix_command(root, command) or command
end

function M.should_root_command(is_go, replaying_last)
  return is_go and not replaying_last
end

function M.run_strategy(command)
  local buffer = vim.api.nvim_get_current_buf()
  local is_go = vim.bo[buffer].filetype == 'go'
  local replaying_last = vim.g.vim_test_replaying_last == true
  local command_with_root = M.command_for_dispatch(
    vim.fn.getcwd(),
    command,
    M.should_root_command(is_go, replaying_last)
  )

  if M.should_root_command(is_go, replaying_last) then
    -- Keep the rooted command as Vim-test's replay target for :TestLast.
    vim.g['test#last_command'] = command_with_root
  end

  if vim.env.HERDR_ENV == '1' then
    vim.fn.HerdrStrategy(command_with_root)
  else
    vim.fn['test#strategy#vimux'](command_with_root)
  end
end

return M
