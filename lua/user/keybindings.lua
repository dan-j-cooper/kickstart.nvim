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

vim.keymap.set('n', '<leader>tf', ':Neotest run<CR>', { desc = '[T]est [F]ile' })
vim.keymap.set('n', '<leader>ts', ':Neotest summary<CR>', { desc = '[T]est [S]ummary' })
vim.keymap.set('n', '<leader>tr', ':Neotest report<CR>', { desc = '[T]est [R]eport' })
