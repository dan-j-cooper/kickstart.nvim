vim.keymap.set('n', '<leader>od', ':Oil --float <CR>', { desc = '[O]pen current [D]irectory', noremap = true, silent = true })
-- run a bash command by copy paste
vim.keymap.set('x', '<leader>e', 'y:<C-r>"<CR>', { noremap = true, silent = false })

-- projects
vim.keymap.set('n', '<leader>sph', ':Telescope neovim-project history<CR>', { desc = '[S]earch [P]roject [H]istory', noremap = true, silent = true })
vim.keymap.set('n', '<leader>spd', ':Telescope neovim-project discover<CR>', { desc = '[S]earch [P]roejct [D]iscover', noremap = true, silent = true })

-- magit
vim.keymap.set('n', '<leader>gg', ':Neogit<CR>', { desc = 'Neo[G]it [G]o', noremap = true, silent = true })

-- refactor.nvim
vim.keymap.set('x', '<leader>re', ':Refactor extract ', { desc = '[R]efactor [e]xtract' })
vim.keymap.set('x', '<leader>rf', ':Refactor extract_to_file ', { desc = '[R]efactor extract to [f]ile' })
vim.keymap.set('x', '<leader>rv', ':Refactor extract_var ', { desc = '[R]efactor extract [v]ar' })
vim.keymap.set({ 'n', 'x' }, '<leader>ri', ':Refactor inline_var', { desc = '[R]efactor [i]nline var' })
vim.keymap.set('n', '<leader>rI', ':Refactor inline_func', { desc = '[R]efactor [i]nline func' })
vim.keymap.set('n', '<leader>rb', ':Refactor extract_block', { desc = '[R]efactor extract [b]lock' })
vim.keymap.set('n', '<leader>rbf', ':Refactor extract_block_to_file', { desc = '[R]efactor extract [b]lock to [f]ile' })

-- neotest
-- vim.keymap.set('n', '<leader>tf', ':Neotest run<CR>', { desc = '[T]est [F]ile' })
-- vim.keymap.set('n', '<leader>ts', ':Neotest summary<CR>', { desc = '[T]est [S]ummary' })
-- vim.keymap.set('n', '<leader>tr', ':Neotest result<CR>', { desc = '[T]est [R]eport' })
local neotest = require 'neotest'

vim.keymap.set('n', '<leader>tt', function()
  neotest.run.run()
end, { desc = 'Run nearest test' })

vim.keymap.set('n', '<leader>tf', function()
  neotest.run.run(vim.fn.expand '%')
end, { desc = 'Run all tests in file' })

vim.keymap.set('n', '<leader>ts', function()
  neotest.summary.toggle()
end, { desc = 'Toggle test summary' })

vim.keymap.set('n', '<leader>to', function()
  neotest.output.open { enter = true }
end, { desc = 'Show test output' })

vim.keymap.set('n', '<leader>tO', function()
  neotest.output_panel.toggle()
end, { desc = 'Toggle output panel' })

vim.keymap.set('n', '<leader>tn', function()
  neotest.jump.next { status = 'failed' }
end, { desc = 'Jump to next failed test' })

vim.keymap.set('n', '<leader>tp', function()
  neotest.jump.prev { status = 'failed' }
end, { desc = 'Jump to previous failed test' })

vim.keymap.set('n', '<leader>ta', function()
  neotest.run.attach()
end, { desc = 'Attach to nearest test' })

vim.keymap.set('n', '<leader>tS', function()
  neotest.run.stop()
end, { desc = 'Stop nearest test' })

-- snippets
vim.keymap.set('n', '<leader>sc', ':Telescope luasnip<CR>')

-- surround with fstring wip
vim.keymap.set('n', '<leader>fs', '[[:normal! viwsa"viwsa{bif<CR>]]', { noremap = true })

vim.api.nvim_create_user_command('GrepAndReplace', function(args)
  local pattern = args.args
  vim.cmd('silent grep' .. vim.fn.shellescape(pattern))
  vim.cmd 'copen'
  vim.api.nvim_feedkeys(':cfdo %s/' .. pattern .. '/', 'n', true)
end, { nargs = 1 })

-- integrate python with tmux
local function SendPythonToTerminal()
  vim.cmd 'write'
  local file = vim.fn.expand '%:p'
  vim.fn.system("tmux send-keys -t terminal:terminal 'python " .. file .. "' C-m Enter")
end

-- python repl
vim.keymap.set('n', '<F9>', SendPythonToTerminal, { desc = 'send python file to terminal' })
-- ctrl-c terminal

local function SendCtrlCToTerminal()
  vim.fn.system 'tmux send-keys -t terminal:terminal C-c Enter'
end
vim.keymap.set('n', '<F10>', SendCtrlCToTerminal, { desc = 'terminate the terminal' })

local function SendRedoToTerminal()
  vim.fn.system 'tmux send-keys -t terminal:terminal !! Enter Enter'
end
vim.keymap.set('n', '<F8>', SendRedoToTerminal, { desc = 'redo last' })

-- ctrlsf, find and replace
vim.keymap.set('n', '<leader>fr', '<Plug>CtrlSFPrompt', { desc = 'find and replace' })

<<<<<<< HEAD
-- tardis
vim.keymap.set('n', '<leader>gt', ':Tardis <CR>', { desc = 'git time machine' })
=======
vim.keymap.set('n', '<leader>fr', '<Plug>CtrlSFPrompt', { desc = 'find and replace' })

-- time machine
vim.keymap.set('n', '<leader>gt', require('agitator').git_time_machine, { desc = 'git time machine' })
>>>>>>> 88554de (updates)

-- portal jumplist
vim.keymap.set('n', '<leader>o', '<cmd>Portal jumplist backward<cr>')
vim.keymap.set('n', '<leader>i', '<cmd>Portal jumplist forward<cr>')

-- set default fold
vim.opt.foldlevel = 5

<<<<<<< HEAD
-- TODO: fix this
=======
>>>>>>> 88554de (updates)
vim.fn.setreg('f', 'ea=}"bbif"{')
