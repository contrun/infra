-- Define commands
-- Swap folder
vim.cmd('command! ListSwap split | enew | r !ls -l ~/.local/share/nvim/swap')
vim.cmd('command! CleanSwap !rm -rf ~/.local/share/nvim/swap/')

-- Open help tags
vim.cmd("command! HelpTags Telescope help_tags")

-- Create ctags
vim.cmd('command! MakeCTags !ctags -R --exclude=@.ctagsignore .')

vim.cmd('language en_US.utf8')

function SmallScreenModeToggle()
  if vim.wo.number then
    SmallScreenModeEnable()
  else
    SmallScreenModeDisable()
  end
end

function SmallScreenModeEnable()
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = 'no'
end

function SmallScreenModeDisable()
  vim.wo.number = true
  vim.wo.relativenumber = true
  vim.wo.signcolumn = 'yes'
end

vim.api.nvim_create_user_command('SmallScreenModeToggle', SmallScreenModeToggle,
  {
    desc = 'Toggle small screen mode to enable/disable maximizied screen usage'
  })

vim.api.nvim_create_user_command('SmallScreenModeEnable', SmallScreenModeEnable,
  {
    desc = 'Enable small screen mode to maximize screen usage'
  })

vim.api.nvim_create_user_command('SmallScreenModeDisable',
  SmallScreenModeDisable, {
    desc = 'Disable small screen mode to allow some gaps'
  })
