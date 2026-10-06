local root = require('custom.vim-test-root')

local function assert_equal(expected, actual)
  assert(expected == actual, ('expected %q, got %q'):format(expected, actual))
end

local temp = vim.fn.tempname()
local previous_herdr_env = vim.env.HERDR_ENV
vim.fn.mkdir(temp .. '/module-a/pkg', 'p')
vim.fn.mkdir(temp .. '/module-b/pkg', 'p')
vim.fn.writefile({ 'module example.com/a' }, temp .. '/module-a/go.mod')
vim.fn.writefile({ 'module example.com/b' }, temp .. '/module-b/go.mod')
vim.fn.writefile({ 'package pkg' }, temp .. '/module-a/pkg/example_test.go')
vim.fn.writefile({ 'package pkg' }, temp .. '/module-b/pkg/example_test.go')

local ok, err = pcall(function()
  local module_a_file = temp .. '/module-a/pkg/example_test.go'
  local module_b_file = temp .. '/module-b/pkg/example_test.go'

  assert_equal(temp .. '/module-a', root.resolve(module_a_file, 'go', '/fallback'))
  assert_equal(temp .. '/module-b', root.resolve(module_b_file, 'go', '/fallback'))
  assert_equal('/fallback', root.resolve(temp .. '/README.md', 'markdown', '/fallback'))
  assert_equal(
    "cd '/tmp/go module' && go test ./...",
    root.command_for_dispatch('/tmp/go module', 'go test ./...', true)
  )
  assert_equal('pytest', root.command_for_dispatch('/tmp/go module', 'pytest', false))
  assert_equal(false, root.should_root_command(true, true))
  assert_equal(true, root.should_root_command(true, false))
  assert_equal(false, root.should_root_command(false, false))

  vim.cmd [[
    function! HerdrStrategy(command) abort
      let g:vim_test_module_root_capture = a:command
    endfunction
  ]]
  vim.env.HERDR_ENV = '1'

  local original_cwd = vim.fn.getcwd()
  vim.cmd('edit ' .. vim.fn.fnameescape(module_a_file))
  vim.bo.filetype = 'go'
  vim.cmd('cd ' .. vim.fn.fnameescape(temp .. '/module-a'))
  root.run_strategy('go test ./...')
  vim.cmd('cd ' .. vim.fn.fnameescape(original_cwd))
  local rooted_command = "cd " .. vim.fn.shellescape(temp .. '/module-a') .. ' && go test ./...'
  assert_equal(rooted_command, vim.g.vim_test_module_root_capture)
  assert_equal(rooted_command, vim.g['test#last_command'])
  assert_equal(nil, vim.g.vim_test_last_rooted)

  vim.cmd('edit ' .. vim.fn.fnameescape(module_b_file))
  vim.bo.filetype = 'go'
  vim.g.vim_test_replaying_last = true
  root.run_strategy(rooted_command)
  vim.g.vim_test_replaying_last = false
  assert_equal(rooted_command, vim.g.vim_test_module_root_capture)

  vim.bo.filetype = 'markdown'
  root.run_strategy('pytest')
  assert_equal('pytest', vim.g.vim_test_module_root_capture)
  assert_equal(nil, vim.g.vim_test_last_rooted)
end)

vim.env.HERDR_ENV = previous_herdr_env
vim.fn.delete(temp, 'rf')
assert(ok, err)
print('vim-test module-root resolver tests passed')
