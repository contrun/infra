-- Plugin definition and loading
local execute = vim.api.nvim_command
local fn = vim.fn
local cmd = vim.cmd

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    "nvim-lua/plenary.nvim",

    -- Formatting
    'shoukoo/commentary.nvim',
    'sbdchd/neoformat',
    {
      'lukas-reineke/lsp-format.nvim',
      config = function() require("lsp-format").setup {} end
    },

    -- Easier navigation
    'junegunn/vim-easy-align',
    'andymass/vim-matchup',

    -- Themes
    'folke/tokyonight.nvim',
    'marko-cerovac/material.nvim',

    'ryvnf/readline.vim',

    -- 'airblade/vim-gitgutter'  -- The standard one I use
    -- Trying out gitsigns
    {
      'lewis6991/gitsigns.nvim',
      dependencies = { 'nvim-lua/plenary.nvim' },
      config = function()
        require('gitsigns').setup {
          on_attach = function(bufnr)
            local gs = package.loaded.gitsigns

            local function map(mode, l, r, opts)
              opts = opts or {}
              opts.buffer = bufnr
              vim.keymap.set(mode, l, r, opts)
            end

            -- Navigation
            map('n', ']c', function()
              if vim.wo.diff then
                return ']c'
              end
              vim.schedule(function()
                gs.next_hunk()
              end)
              return '<Ignore>'
            end, { expr = true })

            map('n', '[c', function()
              if vim.wo.diff then
                return '[c'
              end
              vim.schedule(function()
                gs.prev_hunk()
              end)
              return '<Ignore>'
            end, { expr = true })

            -- Actions
            map({ 'n', 'v' }, '<leader>gs', ':Gitsigns stage_hunk<CR>')
            map({ 'n', 'v' }, '<leader>gr', ':Gitsigns reset_hunk<CR>')
            map('n', '<leader>gS', gs.stage_buffer)
            map('n', '<leader>gu', gs.undo_stage_hunk)
            map('n', '<leader>gR', gs.reset_buffer)
            map('n', '<leader>gp', gs.preview_hunk)
            map('n', '<leader>gb',
              function()
                gs.blame_line { full = true }
              end)
            map('n', '<leader>gd', gs.diffthis)
            map('n', '<leader>gD', function()
              gs.diffthis('~')
            end)
            map('n', '<leader>gtd', gs.toggle_deleted)
            map('n', '<leader>gtb', gs.toggle_current_line_blame)

            -- Text object
            map({ 'o', 'x' }, 'ih', ':<C-U>Gitsigns select_hunk<CR>')
          end
        }
      end
    },

    'rhysd/git-messenger.vim',

    'kassio/neoterm',

    {
      'folke/neodev.nvim',
      config = function()
        require("neodev").setup({
          library = { plugins = { "neotest" }, types = true }
        })
      end
    },

    -- LSP server
    {
      'neovim/nvim-lspconfig',
      dependencies = { "mfussenegger/nvim-jdtls" },
      config = function() require('plugins.lspconfig') end
    },

    { "williamboman/mason.nvim" },
    { "williamboman/mason-lspconfig.nvim" },

    { "Hoffs/omnisharp-extended-lsp.nvim" },
    {
      'ionide/Ionide-vim',
      config = function()
        -- Don't auto setup fsautocomplte for now, we will set it up with lspconfig,
        -- which will also set some useful shortcuts.
        vim.g["fsharp#lsp_auto_setup"] = 0
      end
    },

    -- use({'scalameta/nvim-metals', dependencies = { "nvim-lua/plenary.nvim" }})

    {
      'onsails/lspkind.nvim',
      config = function()
        require('lspkind').init {
          mode = 'symbol_text',
          preset = 'codicons'
        }
      end
    },

    {
      'mfussenegger/nvim-dap',
      dependencies = {
        "Pocco81/dap-buddy.nvim", "theHamsta/nvim-dap-virtual-text",
        "rcarriga/nvim-dap-ui", "mfussenegger/nvim-dap-python",
        "mfussenegger/nvim-jdtls", "nvim-telescope/telescope-dap.nvim",
        "leoluz/nvim-dap-go", "jbyuki/one-small-step-for-vimkind",
        "nvim-neotest/nvim-nio"
      },
      config = function() require('plugins.dapconfig') end
    },

    { "rcarriga/nvim-dap-ui",    dependencies = { "mfussenegger/nvim-dap" } },

    {
      "theHamsta/nvim-dap-virtual-text",
      dependencies = { "mfussenegger/nvim-dap" }
    },

    {
      "nvim-neotest/neotest",
      dependencies = {
        "nvim-lua/plenary.nvim", "nvim-treesitter/nvim-treesitter",
        "antoinemadec/FixCursorHold.nvim",
        "nvim-neotest/neotest-vim-test", "nvim-neotest/neotest-plenary",
        "rouge8/neotest-rust", "nvim-neotest/neotest-python",
        "nvim-neotest/neotest-go", "stevanmilic/neotest-scala",
        "mrcjkb/neotest-haskell", "jfpedroza/neotest-elixir"
      },
      config = function()
        require("neotest").setup({
          adapters = {
            require("neotest-python")({ dap = { justMyCode = false } }),
            require("neotest-plenary"), require("neotest-scala"),
            require("neotest-rust") { args = { "--no-capture" } },
            require("neotest-haskell"), require("neotest-go"),
            require("neotest-vim-test")({
              ignore_file_types = {
                "python", "vim", "lua", "haskell", "elixir",
                "scala", "rust", "go"
              }
            }), require("neotest-go")({
            experimental = { test_table = true },
            args = { "-count=1", "-timeout=60s" }
          })
          }
        })
        -- Suggested keymaps
        local opts = { noremap = true }
        vim.keymap.set('n', '<leader>tt',
          function()
            require('neotest').run.run()
          end, opts)
        vim.keymap.set('n', '<leader>to',
          function()
            require('neotest').output.open()
          end, opts)
        vim.keymap.set('n', '<leader>ta',
          function()
            require("neotest").run.attach()
          end, opts)
        vim.keymap.set('n', '<leader>td', function()
          require("neotest").run.run({ strategy = "dap" })
        end, opts)
        vim.keymap.set('n', '<leader>tf', function()
          require("neotest").run.run(vim.fn.expand("%"))
        end, opts)
        vim.keymap.set('n', '<leader>ts', function()
          require('neotest').summary.toggle()
        end, opts)
      end
    },

    {
      'EthanJWright/vs-tasks.nvim',
      dependencies = {
        'nvim-lua/popup.nvim', 'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim'
      },
      config = function()
        -- Suggested keymaps
        local opts = { noremap = true }
        vim.keymap.set('n', '<leader>ta', function()
          require("telescope").extensions.vstask.tasks()
        end, opts)
        vim.keymap.set('n', '<leader>ti', function()
          require("telescope").extensions.vstask.inputs()
        end, opts)
        vim.keymap.set('n', '<leader>th', function()
          require("telescope").extensions.vstask.history()
        end, opts)
        vim.keymap.set('n', '<leader>tl', function()
          require('telescope').extensions.vstask.launch()
        end, opts)
      end
    },

    -- Autocomplete
    'L3MON4D3/LuaSnip', -- Snippet engine

    'liuchengxu/vista.vim',

    {
      "hrsh7th/nvim-cmp",
      -- Sources for nvim-cmp
      dependencies = {
        "hrsh7th/cmp-nvim-lsp", "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path", "hrsh7th/cmp-nvim-lua",
        "saadparwaiz1/cmp_luasnip"
      },
      config = function() require('plugins.cmp') end
    },

    -- statusline
    {
      'hoob3rt/lualine.nvim',
      config = function() require('plugins.lualine') end
    },

    { 'lambdalisue/suda.vim' },

    { 'wakatime/vim-wakatime' },

    { 'dstein64/vim-startuptime' },

    -- Treesitter
    {
      'nvim-treesitter/nvim-treesitter',
      config = function() require('plugins.treesitter') end,
      run = ':TSUpdate'
    },

    {
      "nvim-treesitter/nvim-treesitter-textobjects",
      dependencies = 'nvim-treesitter/nvim-treesitter',
      config = function()
        require 'nvim-treesitter.configs'.setup {
          textobjects = {
            select = {
              enable = true,
              -- Automatically jump forward to textobj, similar to targets.vim
              lookahead = true,
              keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                ["ic"] = "@class.inner"
              }
            },
            swap = {
              enable = true,
              swap_next = { ["<leader>sa"] = "@parameter.inner" },
              swap_previous = {
                ["<leader>sA"] = "@parameter.inner"
              }
            },
            move = {
              enable = true,
              set_jumps = true, -- whether to set jumps in the jumplist
              goto_next_start = {
                ["]m"] = "@function.outer",
                ["]]"] = "@class.outer"
              },
              goto_next_end = {
                ["]M"] = "@function.outer",
                ["]["] = "@class.outer"
              },
              goto_previous_start = {
                ["[m"] = "@function.outer",
                ["[["] = "@class.outer"
              },
              goto_previous_end = {
                ["[M"] = "@function.outer",
                ["[]"] = "@class.outer"
              }
            },
            lsp_interop = {
              enable = true,
              border = 'none',
              peek_definition_code = {
                ["<leader>lf"] = "@function.outer",
                ["<leader>lF"] = "@class.outer"
              }
            }
          }
        }
      end
    },

    -- TODO: fix
    -- packer.nvim: Error running config for nvim-treesitter-textobjects: ...ed-0.6.1/share/nvim/runtime/lua/vim/treesitter/query.lua:161: query: invalid node type at position 13
    {
      "mizlan/iswap.nvim",
      dependencies = 'nvim-treesitter/nvim-treesitter',
      config = function()
        require('iswap').setup {
          -- The keys that will be used as a selection, in order
          -- ('asdfghjklqwertyuiopzxcvbnm' by default)
          keys = 'qwertyuiop',

          -- Grey out the rest of the text when making a selection
          -- (enabled by default)
          grey = 'disable',

          -- Highlight group for the sniping value (asdf etc.)
          -- default 'Search'
          hl_snipe = 'ErrorMsg',

          -- Highlight group for the visual selection of terms
          -- default 'Visual'
          hl_selection = 'WarningMsg',

          -- Highlight group for the greyed background
          -- default 'Comment'
          hl_grey = 'LineNr',

          -- Automatically swap with only two arguments
          -- default nil
          autoswap = true,

          -- Other default options you probably should not change:
          debug = nil,
          hl_grey_priority = '1000'
        }
      end
    },

    {
      'glacambre/firenvim',
      build = ":call firenvim#install(0)",
      config = function()
        if vim.g.started_by_firenvim == true then
          vim.cmd [[
          let g:firenvim_config = { "globalSettings": { "alt": "all", }, "localSettings": { ".*": { "cmdline": "neovim", "content": "text", "priority": 0, "selector": "textarea", "takeover": "always", }, } }
          let fc = g:firenvim_config["localSettings"]
          let fc["https?://meet.google.com/"] = { "takeover": "never", "priority": 1 }
          let fc["https?://www.notion.so/"] = { "takeover": "never", "priority": 1 }
          let fc["https?://projects.cdk.com/"] = { "takeover": "never", "priority": 1 }
          let fc["https?://stash.cdk.com/"] = { "takeover": "never", "priority": 1 }
          let fc["https?://sonar.cdk.com/"] = { "takeover": "never", "priority": 1 }

          au BufEnter github.com_*.txt set filetype=markdown
          au BufEnter reddit.com_*.txt set filetype=markdown
          au BufEnter go.dev_*.txt set filetype=go
          au BufEnter play.rust-lang.org_*.txt set filetype=rust
          au BufEnter rust-lang.org_*.txt set filetype=rust

          set laststatus=0
          set textwidth=0
          set guifont=Fira_Code:h18,Monaco:h18
          nnoremap <Esc><Esc> :call firenvim#focus_page()<CR>
          au TextChanged * ++nested write
          au TextChangedI * ++nested write
        ]]
        end
      end
    },

    -- TODO: fix
    -- Failed to get context: ...ed-0.6.1/share/nvim/runtime/lua/vim/treesitter/query.lua:161: query: invalid field at position 18
    -- {
    --     "romgrk/nvim-treesitter-context",
    --     config = function()
    --         require'treesitter-context'.setup {
    --             enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
    --             throttle = true, -- Throttles plugin updates (may improve performance)
    --             max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
    --             patterns = { -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
    --                 -- For all filetypes
    --                 -- Note that setting an entry here replaces all other patterns for this entry.
    --                 -- By setting the 'default' entry below, you can control which nodes you want to
    --                 -- appear in the context window.
    --                 default = {
    --                     'class', 'function', 'method'
    --                     -- 'for', -- These won't appear in the context
    --                     -- 'while',
    --                     -- 'if',
    --                     -- 'switch',
    --                     -- 'case',
    --                 },
    --                 -- Example for a specific filetype.
    --                 -- If a pattern is missing, *open a PR* so everyone can benefit.
    --                 rust = {'impl_item'}
    --             },
    --             exact_patterns = {
    --                 -- Example for a specific filetype with Lua patterns
    --                 -- Treat patterns.rust as a Lua pattern (i.e "^impl_item$" will
    --                 -- exactly match "impl_item" only)
    --                 -- rust = true,
    --             }
    --         }
    --     end
    -- }

    'nvim-orgmode/orgmode',

    -- Telescope
    {
      'nvim-telescope/telescope.nvim',
      dependencies = { 'nvim-lua/plenary.nvim' },
      config = function() require('plugins.telescope') end
    },

    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },

    {
      'AckslD/nvim-neoclip.lua',
      config = function()
        require('neoclip').setup {
          history = 1000,
          enable_persistent_history = false,
          length_limit = 1048576,
          continuous_sync = false,
          db_path = vim.fn.stdpath("data") ..
              "/databases/neoclip.sqlite3",
          filter = nil,
          preview = true,
          default_register = '"',
          default_register_macros = 'q',
          enable_macro_history = true,
          content_spec_column = false,
          on_paste = { set_reg = false },
          on_replay = { set_reg = false },
          keys = {
            telescope = {
              i = {
                select = '<cr>',
                paste = '<c-p>',
                paste_behind = '<c-k>',
                replay = '<c-q>', -- replay a macro
                delete = '<c-d>', -- delete an entry
                custom = {}
              },
              n = {
                select = '<cr>',
                paste = 'p',
                paste_behind = 'P',
                replay = 'q',
                delete = 'd',
                custom = {}
              }
            },
            fzf = {
              select = 'default',
              paste = 'ctrl-p',
              paste_behind = 'ctrl-k',
              custom = {}
            }
          }
        }
      end
    },
    {
      'folke/which-key.nvim',
      config = function()
        require("which-key").setup {
          -- your configuration comes here
          -- or leave it empty to use the default settings
          -- refer to the configuration section below
        }
      end
    },

    {
      'aserowy/tmux.nvim',
      config = function()
        require("tmux").setup {
          -- overwrite default configuration
          -- here, e.g. to enable default bindings
          copy_sync = {
            -- enables copy sync and overwrites all register actions to
            -- sync registers *, +, unnamed, and 0 till 9 from tmux in advance
            enable = true
          },
          navigation = {
            -- enables default keybindings (C-hjkl) for normal mode
            enable_default_keybindings = false
          },
          resize = {
            -- enables default keybindings (A-hjkl) for normal mode
            enable_default_keybindings = false
          }
        }
      end
    },

    {
      'folke/trouble.nvim',
      dependencies = 'kyazdani42/nvim-web-devicons',
      config = function()
        require("trouble").setup {
          -- your configuration comes here
          -- or leave it empty to use the default settings
          -- refer to the configuration section below
        }
      end
    },

    -- https://github.com/rockerBOO/awesome-neovim/issues/315
    {
      'ur4ltz/surround.nvim',
      config = function()
        require "surround".setup { mappings_style = "sandwich" }
      end
    },

    { 'fidian/hexmode' },

    { 'sindrets/diffview.nvim',                   dependencies = 'nvim-lua/plenary.nvim' },

    {
      'NeogitOrg/neogit',
      dependencies = {
        'nvim-lua/plenary.nvim', 'sindrets/diffview.nvim',
        'nvim-telescope/telescope.nvim'
      },
      config = function()
        local neogit = require("neogit")
        neogit.setup {
          use_magit_keybindings = true,
          integrations = { diffview = true }
        }
      end,
      lazy = true,
      cmd = { 'Neogit' }
    },

    {
      'ruifm/gitlinker.nvim',
      dependencies = 'nvim-lua/plenary.nvim',
      config = function()
        require "gitlinker".setup({ mappings = "<leader>gy" })
      end
    },

    { 'conweller/findr.vim' },

    --  {
    --    'rmagatti/auto-session',
    --    config = function()
    --      require('auto-session').setup {
    --        auto_session_suppress_dirs = {
    --          '~/', '~/Workspace/', '/tmp/',
    --          '/run/user/1000/firenvim/'
    --        }
    --      }
    --    end
    --  }

    {
      'xvzc/chezmoi.nvim',
      dependencies = { 'nvim-lua/plenary.nvim' },
      config = function()
        require("chezmoi").setup {
          --  e.g. ~/.local/share/chezmoi/*
          vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
            pattern = { os.getenv("HOME") .. "/.local/share/chezmoi/*" },
            callback = function(ev)
              local bufnr = ev.buf
              local edit_watch = function()
                require("chezmoi.commands.__edit").watch(bufnr)
              end
              vim.schedule(edit_watch)
            end,
          })
        }
      end
    },

    { 'gennaro-tedesco/nvim-jqx' },

    { 'github/copilot.vim' },

  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true, notify = false, frequency = 86400 },
})
