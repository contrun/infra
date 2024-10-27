-- Treesitter configuration
local parser_config = require "nvim-treesitter.parsers".get_parser_configs()

require('nvim-treesitter.configs').setup({
  -- If TS highlights are not enabled at all, or disabled via `disable` prop, highlighting will fallback to default Vim syntax highlighting
  highlight = {
    enable = true,
  },
  ensure_installed = "all",
  ignore_install = { "norg" },
})
