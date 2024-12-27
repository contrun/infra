local wezterm = require 'wezterm'

local is_windows = wezterm.target_triple:find 'windows'

-- wezterm.gui is not available to the mux server, so take care to
-- do something reasonable when this config is evaluated by the mux
local function get_appearance()
  if wezterm.gui then return wezterm.gui.get_appearance() end
  return 'Light'
end

local function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then
    return 'Builtin Solarized Dark'
  else
    return 'Builtin Solarized Light'
  end
end

local function strip_sshmux_prefix(domain_name)
  return domain_name:gsub('^SSH[MUX]*:', '')
end

wezterm.on('update-status', function(window)
  -- Grab the utf8 character for the "powerline" left facing
  -- solid arrow.
  local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

  -- Grab the current window's configuration, and from it the
  -- palette (this is the combination of your chosen colour scheme
  -- including any overrides).
  local color_scheme = window:effective_config().resolved_palette
  local bg = color_scheme.background
  local fg = color_scheme.foreground

  window:set_right_status(wezterm.format({
    -- First, we draw the arrow...
    { Background = { Color = 'none' } }, { Foreground = { Color = bg } },
    { Text = SOLID_LEFT_ARROW }, -- Then we draw our text
    { Background = { Color = bg } }, { Foreground = { Color = fg } },
    { Text = ' ' .. wezterm.hostname() .. ' ' }
  }))
end)

-- Show which key table is active in the status area
wezterm.on('update-right-status', function(window, pane)
  local name = window:active_key_table()
  if name then name = 'TABLE: ' .. name end
  window:set_right_status(name or '')
end)

wezterm.on('format-tab-title', function(tab)
  local pane = tab.active_pane
  local title = pane.title
  if pane.domain_name and pane.domain_name ~= 'local' then
    local domain_name = strip_sshmux_prefix(pane.domain_name)
    title = title .. ' - ' .. domain_name
  end
  return title
end)

local default_machine = 'dev'
local default_tls_port = 4443
local sshmux_domain = 'SSHMUX:' .. default_machine
local tlsssh_domain = 'TLSSSH:' .. default_machine
local dev_domain = tlsssh_domain
-- There is a problem while launching the wezterm with tls connection.
-- I encountered
-- mux::connui > while running ConnectionUI loop: recv_timeout: channel is empty and disconnected
-- (os error 267); terminating
-- TODO: Investigate this issue.
if is_windows then
  dev_domain = sshmux_domain
end

local config = {}

config.tls_clients = {}

config.ssh_domains = wezterm.default_ssh_domains()
for _, dom in ipairs(config.ssh_domains) do
  -- Default ssh domains are Posix, but we can override that later.
  dom.assume_shell = 'Posix'
  dom.local_echo_threshold_ms = 10

  -- Create a tls client for each ssh domain.
  -- The dom name here can start with SSH: or SSHMUX:
  -- We remove the prefix here.
  local server_name = strip_sshmux_prefix(dom.name)
  -- TLS connection
  local tls_name = 'TLS:' .. server_name
  -- TLS connection bootstrapped by SSH
  local tls_ssh_name = 'TLSSSH:' .. server_name
  local tls_client_found = false
  for _, tls in ipairs(config.tls_clients) do
    if tls.name == tls_ssh_name then
      tls_client_found = true
      break
    end
  end

  -- If we have already set this name in the tls_config, then just skip
  -- the rest of the loop.
  if not tls_client_found then
    -- My ssh hosts start with default/dev are all aliases for other machines.
    -- We need to find out the real hostnames for these aliases.
    -- Follow https://unix.stackexchange.com/questions/25611/how-to-find-out-the-ip-of-an-ssh-hostname
    -- We can use the command `ssh -G database | awk '/^hostname / { print $2 }'`
    -- to get the real hostname.
    local hostname = dom.remote_address
    if server_name:find '^dev' or server_name:find '^default' then
      -- Don't use shell here, as that would make this config file not portable.
      local success, stdout, _stderr = wezterm.run_child_process { 'ssh', '-G', server_name }
      if success and stdout then
        -- The hostname output should be in the format `hostname <hostname>`
        -- We need to extract the hostname from this output.
        hostname = stdout:match('hostname%s+(%S+)') or hostname
      end
    end

    local remote_address = hostname .. ":" .. default_tls_port
    local tls_conf = {
      name = tls_name,
      remote_address = remote_address,
    }
    local tls_ssh_conf = {
      name = tls_ssh_name,
      remote_address = remote_address,
      bootstrap_via_ssh = server_name
    }

    config.tls_clients[#config.tls_clients + 1] = tls_conf
    config.tls_clients[#config.tls_clients + 1] = tls_ssh_conf
  end
end

config.tls_servers = {
  {
    -- The host:port combination on which the server will listen
    -- for connections
    bind_address = '[::]:4443'
  }
}

config.color_scheme = scheme_for_appearance(get_appearance())

-- Generate launch_menu items for the domain
local function generate_launch_menu(domain)
  return {
    {
      label = 'wezterm cli spawn --domain-name ' .. domain,
      args = { 'wezterm', 'cli', 'spawn', '--domain-name', domain }
    },
    {
      label = 'wezterm connect ' .. domain,
      args = { 'wezterm', 'connect', domain }
    }
  }
end

config.launch_menu = {
  table.unpack(generate_launch_menu(sshmux_domain)),
  table.unpack(generate_launch_menu(tlsssh_domain))
}

-- timeout_milliseconds defaults to 1000 and can be omitted
config.leader = { key = 'Space', mods = 'CTRL|SHIFT', timeout_milliseconds = 1000 }
config.keys = {
  {
    key = 'Space',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.DisableDefaultAssignment,
  },
  {
    key = 'Space',
    mods = 'LEADER|CTRL|SHIFT',
    action = wezterm.action.SendKey { key = 'Space', mods = 'CTRL|SHIFT' },
  },
  {
    key = '"',
    mods = 'LEADER|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = '%',
    mods = 'LEADER|SHIFT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'd',
    mods = 'LEADER|CTRL|SHIFT',
    action = wezterm.action.ShowDebugOverlay,
  },
  {
    key = 's',
    mods = 'CTRL|ALT',
    action = wezterm.action.QuickSelect,
  },
  {
    key = 'o',
    mods = 'CTRL|ALT',
    action = wezterm.action.QuickSelectArgs {
      label = 'open url',
      patterns = {
        'https?://\\S+',
      },
      action = wezterm.action_callback(function(window, pane)
        local url = window:get_selection_text_for_pane(pane)
        wezterm.log_info('opening: ' .. url)
        wezterm.open_with(url)
      end),
    },
  },

  {
    key = 't',
    mods = 'CTRL|ALT',
    action = wezterm.action.SpawnTab 'DefaultDomain',
  },
  {
    key = 'a',
    mods = 'CTRL|ALT',
    action = wezterm.action.AttachDomain(dev_domain),
  },
  {
    key = 'd',
    mods = 'CTRL|ALT',
    action = wezterm.action.DetachDomain {
      DomainName = dev_domain
    },
  },
  {
    key = 'l',
    mods = 'CTRL|ALT',
    action = wezterm.action.ShowLauncher,
  },
  {
    key = 'h',
    mods = 'CTRL|ALT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'v',
    mods = 'CTRL|ALT',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'n',
    mods = 'CTRL|ALT',
    action = wezterm.action.ActivatePaneDirection 'Next',
  },
  {
    key = 'p',
    mods = 'CTRL|ALT',
    action = wezterm.action.ActivatePaneDirection 'Prev',
  },

  -- CTRL+SHIFT+Space, followed by 'r' will put us in resize-pane
  -- mode until we cancel that mode.
  {
    key = 'r',
    mods = 'LEADER',
    action = wezterm.action.ActivateKeyTable {
      name = 'resize_pane',
      one_shot = false,
    },
  },

  -- CTRL+SHIFT+Space, followed by 'a' will put us in activate-pane
  -- mode until we press some other key or until 1 second (1000ms)
  -- of time elapses
  {
    key = 'a',
    mods = 'LEADER',
    action = wezterm.action.ActivateKeyTable {
      name = 'activate_pane',
      timeout_milliseconds = 1000,
    },
  },
}

config.key_tables = {
  -- Defines the keys that are active in our resize-pane mode.
  -- Since we're likely to want to make multiple adjustments,
  -- we made the activation one_shot=false. We therefore need
  -- to define a key assignment for getting out of this mode.
  -- 'resize_pane' here corresponds to the name="resize_pane" in
  -- the key assignments above.
  resize_pane = {
    { key = 'LeftArrow',  action = wezterm.action.AdjustPaneSize { 'Left', 1 } },
    { key = 'h',          action = wezterm.action.AdjustPaneSize { 'Left', 1 } },

    { key = 'RightArrow', action = wezterm.action.AdjustPaneSize { 'Right', 1 } },
    { key = 'l',          action = wezterm.action.AdjustPaneSize { 'Right', 1 } },

    { key = 'UpArrow',    action = wezterm.action.AdjustPaneSize { 'Up', 1 } },
    { key = 'k',          action = wezterm.action.AdjustPaneSize { 'Up', 1 } },

    { key = 'DownArrow',  action = wezterm.action.AdjustPaneSize { 'Down', 1 } },
    { key = 'j',          action = wezterm.action.AdjustPaneSize { 'Down', 1 } },

    -- Cancel the mode by pressing escape
    { key = 'Escape',     action = 'PopKeyTable' },
  },

  -- Defines the keys that are active in our activate-pane mode.
  -- 'activate_pane' here corresponds to the name="activate_pane" in
  -- the key assignments above.
  activate_pane = {
    { key = 'LeftArrow',  action = wezterm.action.ActivatePaneDirection 'Left' },
    { key = 'h',          action = wezterm.action.ActivatePaneDirection 'Left' },

    { key = 'RightArrow', action = wezterm.action.ActivatePaneDirection 'Right' },
    { key = 'l',          action = wezterm.action.ActivatePaneDirection 'Right' },

    { key = 'UpArrow',    action = wezterm.action.ActivatePaneDirection 'Up' },
    { key = 'k',          action = wezterm.action.ActivatePaneDirection 'Up' },

    { key = 'DownArrow',  action = wezterm.action.ActivatePaneDirection 'Down' },
    { key = 'j',          action = wezterm.action.ActivatePaneDirection 'Down' },
  },
}

if is_windows then
  config.default_prog = { 'powershell.exe' }
  -- https://github.com/wez/wezterm/discussions/3772#discussioncomment-7201688
  config.ssh_backend = "Ssh2"
end

return config
