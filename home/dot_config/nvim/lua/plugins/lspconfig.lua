-- lua/plugins/lspconfig.lua

local function common_on_attach(client, bufnr)
  -- Set omnifunc.
  vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

  -- Buffer-local keybindings.
  local opts = {
    noremap = false,
    silent = true,
    buffer = bufnr,
  }

  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, opts)
  end

  -- Navigation.
  map("gd", vim.lsp.buf.definition)
  map("gD", vim.lsp.buf.declaration)
  map("gi", "<cmd>Telescope lsp_implementations<CR>")
  map("gr", "<cmd>Telescope lsp_references<CR>")
  map("gR", vim.lsp.buf.rename)

  -- Documentation and signature help.
  map("K", vim.lsp.buf.hover)
  map("<C-k>", vim.lsp.buf.signature_help)

  -- Workspace folders.
  map("<leader>lw", vim.lsp.buf.add_workspace_folder)
  map("<leader>lr", vim.lsp.buf.remove_workspace_folder)

  map("<leader>lW", function()
    print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
  end)

  -- Symbols and navigation.
  map("<leader>lv", "<cmd>Vista nvim_lsp<CR>")
  map("<leader>lt", vim.lsp.buf.type_definition)
  map("<leader>ls", "<cmd>Telescope lsp_document_symbols<CR>")
  map("<leader>l/", "<cmd>Telescope lsp_workspace_symbols<CR>")

  -- Code actions.
  map("<leader>la", vim.lsp.buf.code_action)

  -- Diagnostics.
  map("<leader>le", vim.diagnostic.open_float)
  map("[d", vim.diagnostic.goto_prev)
  map("]d", vim.diagnostic.goto_next)
  map("<leader>lq", vim.diagnostic.setloclist)

  -- OmniSharp semantic-token workaround.
  if client.name == "omnisharp"
      and client.server_capabilities.semanticTokensProvider then
    client.server_capabilities.semanticTokensProvider.legend = {
      tokenModifiers = { "static" },
      tokenTypes = {
        "comment", "excluded", "identifier", "keyword", "keyword",
        "number", "operator", "operator", "preprocessor", "string",
        "whitespace", "text", "static", "preprocessor", "punctuation",
        "string", "string", "class", "delegate", "enum", "interface",
        "module", "struct", "typeParameter", "field", "enumMember",
        "constant", "local", "parameter", "method", "method",
        "property", "event", "namespace", "label", "xml", "xml",
        "xml", "xml", "xml", "xml", "xml", "xml", "xml", "xml",
        "xml", "xml", "regexp", "regexp", "regexp", "regexp",
        "regexp", "regexp", "regexp",
      },
    }
  end

  -- Formatting integration.
  require("lsp-format").on_attach(client)
end

-- Floating-window highlights.
local highlight_group = vim.api.nvim_create_augroup(
  "LspFloatHighlights",
  { clear = true }
)

local function set_float_highlights()
  vim.api.nvim_set_hl(0, "NormalFloat", {
    bg = "#1f2335",
  })

  vim.api.nvim_set_hl(0, "FloatBorder", {
    fg = "white",
    bg = "#1f2335",
  })
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = highlight_group,
  callback = set_float_highlights,
})

set_float_highlights()

-- Export the shared on_attach callback.
return {
  common_on_attach = common_on_attach,
}
