local get_servers_to_install = function()
  local servers_to_install = {
    "clangd", "pyright", "jsonls", "dockerls", "rust_analyzer", "elixirls",
    "zls", "gopls", "texlab", "denols"
  }
  return servers_to_install
end

local get_no_installing_servers = function()
  local servers_unable_to_install = {
    "bashls", "hls", "ts_ls", "jsonls", "omnisharp", "fsautocomplete", "nixd"
  }
  return servers_unable_to_install
end

local lsp_config = require('lspconfig')
local lsp_utils = require('lsp.utils')

local common_on_attach = lsp_utils.common_on_attach
local capabilities = require('cmp_nvim_lsp').default_capabilities()

local setup_servers = function()
  local setup_server = function(server)
    local default_options = {
      on_attach = common_on_attach,
      capabilities = capabilities
    }

    -- Now we'll create a server_default table where we'll specify our custom LSP server configuration
    local server_specific_options = {
      ["denols"] = function(options)
        options.single_file_support = true
        return options
      end,
      ["bashls"] = function(options)
        options.single_file_support = true
        return options
      end,
      -- Provide settings that should only apply to the "eslintls" server
      ["eslintls"] = function(options)
        options.settings = { format = { enable = true } }
        return options
      end,
      ["omnisharp"] = function(options)
        options.handlers = {
          ["textDocument/definition"] = require('omnisharp_extended').handler
        }
        local omnisharp_bin
        for _, bin in ipairs({ "omnisharp", "OmniSharp" }) do
          if vim.fn.executable(bin) == 1 then
            omnisharp_bin = bin
            break
          end
        end
        if omnisharp_bin then
          local pid = vim.fn.getpid()
          options.cmd = {
            omnisharp_bin, "--languageserver", "--hostPID",
            tostring(pid)
          }
        end
        return options
      end
    }

    local options = server_specific_options[server] and
        server_specific_options[server](default_options) or
        default_options

    if lsp_config[server] then lsp_config[server].setup(options) end
  end

  for _, server in ipairs(get_servers_to_install()) do setup_server(server) end

  for _, server in ipairs(get_no_installing_servers()) do
    setup_server(server)
  end
end

setup_servers()
require('lsp.sumneko')
