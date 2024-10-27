-- Load all config files
require('commands')
require('options')
require('keymaps')
require('plugins')
require('themes') -- Theme at the end, to prevent overwrite by other plugins
