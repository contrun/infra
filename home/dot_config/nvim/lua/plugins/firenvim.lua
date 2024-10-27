local M = {}

local function config()
  vim.cmd [[let g:firenvim_config = { "globalSettings": { "alt": "all", }, "localSettings": { ".*": { "cmdline": "neovim", "content": "text", "priority": 0, "selector": "textarea", "takeover": "always", }, } }]]
  vim.cmd('let fc = g:firenvim_config["localSettings"]')
  vim.cmd [[let fc["https?://projects.cdk.com/"] = { "takeover": "never", "priority": 1 }]]
  vim.cmd [[let fc["https?://stash.cdk.com/"] = { "takeover": "never", "priority": 1 }]]
  vim.cmd [[let fc["https?://sonar.cdk.com/"] = { "takeover": "never", "priority": 1 }]]
end

local function is_firenvim()
  return vim.g.started_by_firenvim == true
end

local function is_not_firenvim()
  return vim.g["started_by_firenvim"] == nil
end

local function init()
  if is_firenvim() then
    vim.cmd [[au BufEnter github.com_*.txt set filetype=shell]]
    vim.cmd [[au BufEnter reddit.com_*.txt set filetype=markdown]]
    vim.cmd [[set laststatus=0]]
    vim.cmd [[set textwidth=0]]
    vim.cmd [[set guifont=Fira_Code:h18]]
    vim.cmd [[echo "test2"]]
  end
end

M.config = config
M.is_firenvim = is_firenvim
M.is_not_firenvim = is_not_firenvim

M.init = init

return M
