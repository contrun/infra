-- Lualine configuration
local non_language_ft = { 'fugitive', 'startify' }

local custom_fname = require('lualine.components.filename'):extend()
local highlight = require 'lualine.highlight'
local default_status_colors = { saved = '#228B22', modified = '#C70039' }

function custom_fname:init(options)
  custom_fname.super.init(self, options)
  self.status_colors = {
    saved = highlight.create_component_highlight_group({
      bg = default_status_colors.saved
    }, 'filename_status_saved', self.options),
    modified = highlight.create_component_highlight_group({
      bg = default_status_colors.modified
    }, 'filename_status_modified', self.options)
  }
  if self.options.color == nil then self.options.color = '' end
end

function custom_fname:update_status()
  local data = custom_fname.super.update_status(self)
  data = highlight.component_format_highlight(vim.bo.modified and
        self.status_colors.modified or
        self.status_colors.saved) ..
      data
  return data
end

require('lualine').setup {
  options = { theme = "auto", icons_enabled = true },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff' },
    lualine_c = {
      'filetype', {
      function()
        local msg = 'No LSP'
        local buf_ft = vim.api.nvim_buf_get_option(0, 'filetype')
        local clients = vim.lsp.get_active_clients()

        if next(clients) == nil then return msg end

        -- Check for utility buffers
        for ft in non_language_ft do
          if ft:match(buf_ft) then
            return ''
          end
        end

        for _, client in ipairs(clients) do
          local filetypes = client.config.filetypes

          if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
            -- return 'LSP:'..client.name  -- Return LSP name
            return '' -- Only display if no LSP is found
          end
        end

        return msg
      end,
      color = { fg = '#ffffff', gui = 'bold' },
      separator = ""
    }, {
      'diagnostics',
      sources = { 'nvim_diagnostic' },
      sections = { 'error', 'warn', 'info' }
    }, custom_fname
    },
    lualine_x = { 'encoding', 'fileformat', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' }
  }
}
