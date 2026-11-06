local config_root = vim.fn.getcwd()
local spec = dofile(config_root .. '/nvim/.config/nvim/lua/custom/plugins/herdr-nvim.lua')

local function assert_equal(expected, actual)
  assert(expected == actual, ('expected %s, got %s'):format(vim.inspect(expected), vim.inspect(actual)))
end

local function keymap(lhs, mode)
  for _, mapping in ipairs(spec.keys) do
    if mapping[1] == lhs and mapping.mode == mode then
      return mapping
    end
  end
end

assert_equal('<CMD>Herdr comment<CR>', keymap('<leader>ac', 'n')[2])
assert_equal('<CMD>Herdr ref<CR>', keymap('<leader>ai', 'n')[2])

local comment_selection = keymap('<leader>ac', 'x')
local ref_selection = keymap('<leader>ai', 'x')
assert(comment_selection, 'missing visual <leader>ac mapping')
assert(ref_selection, 'missing visual <leader>ai mapping')
assert(type(comment_selection[2]) == 'function', 'visual <leader>ac must use a callback')
assert(type(ref_selection[2]) == 'function', 'visual <leader>ai must use a callback')

local original_herdr = package.loaded['herdr-nvim']
local calls = { comment = 0, ref = 0 }
package.loaded['herdr-nvim'] = {
  comment_selection = function()
    calls.comment = calls.comment + 1
  end,
  ref_selection = function()
    calls.ref = calls.ref + 1
  end,
}

local ok, err = pcall(function()
  comment_selection[2]()
  assert_equal(1, calls.comment)
  assert_equal(0, calls.ref)

  ref_selection[2]()
  assert_equal(1, calls.comment)
  assert_equal(1, calls.ref)
end)

package.loaded['herdr-nvim'] = original_herdr
assert(ok, err)

print 'herdr-nvim visual keymap tests passed'
