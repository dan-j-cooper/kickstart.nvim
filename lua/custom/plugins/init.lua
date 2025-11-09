-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'CopilotC-Nvim/CopilotChat.nvim',
    dependencies = {
      { 'nvim-lua/plenary.nvim', branch = 'master' },
    },
    build = 'make tiktoken',
    opts = {
      providers = {
        lmstudio = {
          prepare_input = function(inputs, opts)
            local is_o1 = vim.startswith(opts.model.id, 'o1')

            -- Check if this model uses the Responses API
            if opts.model.use_responses then
              -- Prepare input for Responses API
              local instructions = nil
              local input_messages = {}

              for _, msg in ipairs(inputs) do
                if msg.role == constants.ROLE.SYSTEM then
                  -- Combine system messages as instructions
                  if instructions then
                    instructions = instructions .. '\n\n' .. msg.content
                  else
                    instructions = msg.content
                  end
                else
                  -- Include the message in the input array
                  table.insert(input_messages, {
                    role = msg.role,
                    content = msg.content,
                  })
                end
              end

              -- The Responses API expects the input field to be an array of message objects
              local out = {
                model = opts.model.id,
                -- Always request streaming for Responses API (honor model.streaming or default to true)
                stream = opts.model.streaming ~= false,
                input = input_messages,
              }

              -- Add instructions if we have any system messages
              if instructions then
                out.instructions = instructions
              end

              -- Add tools for Responses API if available
              if opts.tools and opts.model.tools then
                out.tools = vim.tbl_map(function(tool)
                  return {
                    type = 'function',
                    ['function'] = {
                      name = tool.name,
                      description = tool.description,
                      parameters = tool.schema,
                      strict = true,
                    },
                  }
                end, opts.tools)
              end

              -- Note: temperature is not supported by Responses API, so we don't include it

              return out
            end

            -- Original Chat Completion API logic
            inputs = vim.tbl_map(function(input)
              local output = {
                role = input.role,
                content = input.content,
              }

              if is_o1 then
                if input.role == constants.ROLE.SYSTEM then
                  output.role = constants.ROLE.USER
                end
              end

              if input.tool_call_id then
                output.tool_call_id = input.tool_call_id
              end

              if input.tool_calls then
                output.tool_calls = vim.tbl_map(function(tool_call)
                  return {
                    id = tool_call.id,
                    type = 'function',
                    ['function'] = {
                      name = tool_call.name,
                      arguments = tool_call.arguments or nil,
                    },
                  }
                end, input.tool_calls)
              end

              return output
            end, inputs)

            local out = {
              messages = inputs,
              model = opts.model.id,
              stream = opts.model.streaming or false,
            }

            if opts.tools and opts.model.tools then
              out.tools = vim.tbl_map(function(tool)
                return {
                  type = 'function',
                  ['function'] = {
                    name = tool.name,
                    description = tool.description,
                    parameters = tool.schema,
                  },
                }
              end, opts.tools)
            end

            if not is_o1 then
              out.n = 1
              out.top_p = 1
              out.temperature = opts.temperature
            end

            if opts.model.max_output_tokens then
              out.max_tokens = opts.model.max_output_tokens
            end

            return out
          end,

          prepare_output = function(output, opts)
            -- Check if this model uses the Responses API
            if opts and opts.model and opts.model.use_responses then
              -- Handle Responses API output format
              local content = ''
              local reasoning = ''
              local finish_reason = nil
              local total_tokens = 0
              local tool_calls = {}

              -- Check for error in response
              if output.error then
                -- Surface the error as a finish reason to stop processing
                local error_msg = output.error
                if type(error_msg) == 'table' then
                  error_msg = error_msg.message or vim.inspect(error_msg)
                end
                return {
                  content = '',
                  reasoning = '',
                  finish_reason = 'error: ' .. tostring(error_msg),
                  total_tokens = nil,
                  tool_calls = {},
                }
              end

              if output.type then
                -- This is a streaming response from Responses API
                if output.type == 'response.created' or output.type == 'response.in_progress' then
                  -- In-progress events, we don't have content yet
                  return {
                    content = '',
                    reasoning = '',
                    finish_reason = nil,
                    total_tokens = nil,
                    tool_calls = {},
                  }
                elseif output.type == 'response.completed' then
                  -- Completed response: do NOT resend content here to avoid duplication.
                  -- Only signal finish and capture usage/reasoning.
                  local response = output.response
                  if response then
                    if response.reasoning and response.reasoning.summary then
                      reasoning = response.reasoning.summary
                    end
                    if response.usage then
                      total_tokens = response.usage.total_tokens
                    end
                    finish_reason = 'stop'
                  end
                  return {
                    content = '',
                    reasoning = reasoning,
                    finish_reason = finish_reason,
                    total_tokens = total_tokens,
                    tool_calls = {},
                  }
                elseif output.type == 'response.content.delta' or output.type == 'response.output_text.delta' then
                  -- Streaming content delta
                  if output.delta then
                    if type(output.delta) == 'string' then
                      content = output.delta
                    elseif type(output.delta) == 'table' then
                      if output.delta.content then
                        content = output.delta.content
                      elseif output.delta.output_text then
                        content = extract_text_from_parts { output.delta.output_text }
                      elseif output.delta.text then
                        content = output.delta.text
                      end
                    end
                  end
                elseif output.type == 'response.delta' then
                  -- Handle response.delta with nested output_text
                  if output.delta and output.delta.output_text then
                    content = extract_text_from_parts { output.delta.output_text }
                  end
                elseif output.type == 'response.content.done' or output.type == 'response.output_text.done' then
                  -- Terminal content event; keep streaming open until response.completed provides usage info
                  finish_reason = nil
                elseif output.type == 'response.error' then
                  -- Handle error event
                  local error_msg = output.error
                  if type(error_msg) == 'table' then
                    error_msg = error_msg.message or vim.inspect(error_msg)
                  end
                  finish_reason = 'error: ' .. tostring(error_msg)
                elseif output.type == 'response.tool_call.delta' then
                  -- Handle tool call delta events
                  if output.delta and output.delta.tool_calls then
                    for _, tool_call in ipairs(output.delta.tool_calls) do
                      local id = tool_call.id or ('tooluse_' .. (tool_call.index or 1))
                      local existing_call = nil
                      for _, tc in ipairs(tool_calls) do
                        if tc.id == id then
                          existing_call = tc
                          break
                        end
                      end
                      if not existing_call then
                        table.insert(tool_calls, {
                          id = id,
                          index = tool_call.index or #tool_calls + 1,
                          name = tool_call.name or '',
                          arguments = tool_call.arguments or '',
                        })
                      else
                        -- Append arguments
                        existing_call.arguments = existing_call.arguments .. (tool_call.arguments or '')
                      end
                    end
                  end
                end
              elseif output.response then
                -- Non-streaming response or final response
                local response = output.response

                -- Check for error in the response object
                if response.error then
                  local error_msg = response.error
                  if type(error_msg) == 'table' then
                    error_msg = error_msg.message or vim.inspect(error_msg)
                  end
                  return {
                    content = '',
                    reasoning = '',
                    finish_reason = 'error: ' .. tostring(error_msg),
                    total_tokens = nil,
                    tool_calls = {},
                  }
                end

                if response.output and #response.output > 0 then
                  for _, msg in ipairs(response.output) do
                    if msg.content and #msg.content > 0 then
                      content = content .. extract_text_from_parts(msg.content)
                    end
                    -- Extract tool calls from output messages
                    if msg.tool_calls then
                      for i, tool_call in ipairs(msg.tool_calls) do
                        local id = tool_call.id or ('tooluse_' .. i)
                        table.insert(tool_calls, {
                          id = id,
                          index = tool_call.index or i,
                          name = tool_call.name or '',
                          arguments = tool_call.arguments or '',
                        })
                      end
                    end
                  end
                end

                if response.reasoning and response.reasoning.summary then
                  reasoning = response.reasoning.summary
                end

                if response.usage then
                  total_tokens = response.usage.total_tokens
                end

                finish_reason = response.status == 'completed' and 'stop' or nil
              end

              return {
                content = content,
                reasoning = reasoning,
                finish_reason = finish_reason,
                total_tokens = total_tokens,
                tool_calls = tool_calls,
              }
            end

            -- Original Chat Completion API logic
            local tool_calls = {}

            local choice
            if output.choices and #output.choices > 0 then
              for _, choice in ipairs(output.choices) do
                local message = choice.message or choice.delta
                if message and message.tool_calls then
                  for i, tool_call in ipairs(message.tool_calls) do
                    local fn = tool_call['function']
                    if fn then
                      local index = tool_call.index or i
                      local id = utils.empty(tool_call.id) and ('tooluse_' .. index) or tool_call.id
                      table.insert(tool_calls, {
                        id = id,
                        index = index,
                        name = fn.name,
                        arguments = fn.arguments or '',
                      })
                    end
                  end
                end
              end

              choice = output.choices[1]
            else
              choice = output
            end

            local message = choice.message or choice.delta
            local content = message and message.content
            local reasoning = message and (message.reasoning or message.reasoning_content)
            local usage = choice.usage and choice.usage.total_tokens
            if not usage then
              usage = output.usage and output.usage.total_tokens
            end
            local finish_reason = choice.finish_reason or choice.done_reason or output.finish_reason or output.done_reason

            return {
              content = content,
              reasoning = reasoning,
              finish_reason = finish_reason,
              total_tokens = usage,
              tool_calls = tool_calls,
            }
          end,

          get_models = function(headers)
            local response, err = require('CopilotChat.utils').curl_get('http://localhost:1234/v1/models', {
              headers = headers,
              json_response = true,
            })

            if err then
              error(err)
            end

            return vim.tbl_map(function(model)
              return {
                id = model.id,
                name = model.id,
              }
            end, response.body.data)
          end,

          get_url = function()
            return 'http://localhost:1234/v1/chat/completions'
          end,
        },
      },
    },
  },
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
  },
  {
    'kkoomen/vim-doge',
  },
  {
    'sedm0784/vim-you-autocorrect',
  },
  {
    'subnut/nvim-ghost.nvim',
  },
  {
    'coffebar/neovim-project',
    opts = {
      projects = { -- define project roots
        '~/Code/*',
        '~/.config/*',
      },
    },
    init = function()
      -- enable saving the state of plugins in the session
      vim.opt.sessionoptions:append 'globals' -- save global variables that start with an uppercase letter and contain at least one lowercase letter.
    end,
    dependencies = {
      { 'nvim-lua/plenary.nvim' },
      { 'nvim-telescope/telescope.nvim', tag = '0.1.4' },
      { 'Shatur/neovim-session-manager' },
    },
    lazy = false,
    priority = 100,
  },
  {
    'itspriddle/vim-shellcheck',
  },
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim', -- required
      'sindrets/diffview.nvim', -- optional - Diff integration

      -- Only one of these is needed, not both.
      'nvim-telescope/telescope.nvim', -- optional
      'ibhagwan/fzf-lua', -- optional
    },
    config = true,
  },
  {
    'stevearc/oil.nvim',
    opts = {},
    -- Optional dependencies
    dependencies = { { 'echasnovski/mini.icons', opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
  },
  {
    'folke/trouble.nvim',
    cmd = 'Trouble',
  },
  {
    'nvim-neotest/neotest-python',
  },
  {
    'ThePrimeagen/refactoring.nvim',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    config = function()
      require('refactoring').setup {}
    end,
  },
  {
    'fredeeb/tardis.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = true,
    opts = {
      keymap = {
        ['next'] = '<C-q>',
        ['prev'] = '<C-w>',
      },
    },
  },
  {
    'emmanueltouzery/agitator.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'nvim-telescope/telescope.nvim' },
  },
  -- {
  --   'fredeeb/tardis.nvim',
  --   dependencies = { 'nvim-lua/plenary.nvim' },
  --   config = true,
  --   opts = {
  --     keymap = {
  --       ['next'] = '<C-y>',
  --       ['prev'] = '<C-h>',
  --       ['quit'] = 'q', -- quit all
  --       ['revision_message'] = '<C-m>', -- show revision message for current revision
  --       ['commit'] = '<C-g>', -- replace contents of origin buffer with contents of tardis buffer
  --     },
  --     initial_revisions = 10, -- initial revisions to create buffers for
  --     max_revisions = 256, -- max number of revisions to load
  --   },
  -- },
  {
    'rmagatti/auto-session',
    lazy = false,
    dependencies = {
      'nvim-telescope/telescope.nvim', -- Only needed if you want to use session lens
    },

    ---enables autocomplete for opts
    ---@module "auto-session"
    ---@type AutoSession.Config
    opts = {
      suppressed_dirs = { '~/', '~/Projects', '~/Downloads', '/' },
      -- log_level = 'debug',
    },
  },
  {
    'nvim-orgmode/orgmode',
    event = 'VeryLazy',
    ft = { 'org' },
    config = function()
      -- Setup orgmode
      require('orgmode').setup {
        org_agenda_files = '~/orgfiles/**/*',
        org_default_notes_file = '~/orgfiles/refile.org',
      }

      -- NOTE: If you are using nvim-treesitter with ~ensure_installed = "all"~ option
      -- add ~org~ to ignore_install
      -- require('nvim-treesitter.configs').setup({
      --   ensure_installed = 'all',
      --   ignore_install = { 'org' },
      -- })
    end,
  },
  {
    'nvim-orgmode/telescope-orgmode.nvim',
    event = 'VeryLazy',
    dependencies = {
      'nvim-orgmode/orgmode',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require('telescope').load_extension 'orgmode'

      vim.keymap.set('n', '<leader>so', require('telescope').extensions.orgmode.search_headings, { desc = '[S]earch [O]rgmode' })
    end,
  },
  {
    'nvim-orgmode/telescope-orgmode.nvim',
    event = 'VeryLazy',
    dependencies = {
      'nvim-orgmode/orgmode',
      'nvim-telescope/telescope.nvim',
    },
    config = function()
      require('telescope').load_extension 'orgmode'

      vim.keymap.set('n', '<leader>so', require('telescope').extensions.orgmode.search_headings, { desc = '[S]earch [O]rgmode' })
    end,
  },
  {
    'nvim-neotest/neotest-python',
  },
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
    },
    opts = {
      adapters = {
        ['neotest-python'] = {
          dap = { justMyCode = false },
          args = { '--log-level', 'DEBUG', '--verbose', '-s' },
          runner = 'pytest',
          -- is_test_file = function(file_path)
          --   if string.find(file_path, 'test') and vim.endswith(file_path, '.py') then
          --     return true
          --   end
          --   return false
          -- end,
        },
      },
      status = { virtual_text = true },
      output = { open_on_run = true },
      quickfix = {
        open = function()
          require('trouble').open { mode = 'quickfix', focus = false }
        end,
      },
      debug = true,
    },
  },
  -- {
  --       ['neotest-python'] = {
  --         dap = { justMyCode = false },
  --         args = { '--log-level', 'DEBUG', '--verbose', '-s' },
  --         runner = 'pytest',
  --         is_test_file = function(file_path)
  --           if string.find(file_path, 'test') and vim.endswith(file_path, '.py') then
  --             return true
  --           end
  --           return false
  --         end,
  --       },
  --       status = { virtual_text = true },
  --       output = { open_on_run = true },
  --       quickfix = {
  --         open = function()
  --           require('trouble').open { mode = 'quickfix', focus = false }
  --         end,
  --       },
  --     },
  --   },
  -- },
  {
    'gabrielpoca/replacer.nvim',
    opts = {
      rename_files = true,
    },
    keys = {
      {
        '<leader>oq',
        function()
          require('replacer').run()
        end,
        desc = 'run replacer.nvim',
      },
    },
  },
  {
    'dyng/ctrlsf.vim',
  },
  {
    'cbochs/portal.nvim',
    -- Optional dependencies
    dependencies = {
      'cbochs/grapple.nvim',
      'ThePrimeagen/harpoon',
    },
    {
      'folke/trouble.nvim',
      opts = {}, -- for default options, refer to the configuration section for custom setup.
      cmd = 'Trouble',
      keys = {
        {
          '<leader>xx',
          '<cmd>Trouble diagnostics toggle<cr>',
          desc = 'Diagnostics (Trouble)',
        },
        {
          '<leader>xX',
          '<cmd>Trouble diagnostics toggle filter.buf=0<cr>',
          desc = 'Buffer Diagnostics (Trouble)',
        },
        {
          '<leader>cs',
          '<cmd>Trouble symbols toggle focus=false<cr>',
          desc = 'Symbols (Trouble)',
        },
        {
          '<leader>cl',
          '<cmd>Trouble lsp toggle focus=false win.position=right<cr>',
          desc = 'LSP Definitions / references / ... (Trouble)',
        },
        {
          '<leader>xL',
          '<cmd>Trouble loclist toggle<cr>',
          desc = 'Location List (Trouble)',
        },
        {
          '<leader>xQ',
          '<cmd>Trouble qflist toggle<cr>',
          desc = 'Quickfix List (Trouble)',
        },
      },
    },
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
  },
  {
    'tmhedberg/SimpylFold',
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
  },
  {
    'mrcjkb/rustaceanvim',
    version = '^5', -- Recommended
    lazy = false, -- This plugin is already lazy
  },
  {
    'NoahTheDuke/vim-just',
  },
  {
    'benlubas/molten-nvim',
    version = '^1.0.0', -- use version <2.0.0 to avoid breaking changes
    build = ':UpdateRemotePlugins',
    init = function()
      -- this is an example, not a default. Please see the readme for more configuration options
      vim.g.molten_output_win_max_height = 12
    end,
  },
}
