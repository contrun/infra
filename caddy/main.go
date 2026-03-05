package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	// plug in Caddy modules here
	_ "github.com/caddy-dns/cloudflare"
	_ "github.com/caddyserver/replace-response"
	_ "github.com/greenpau/caddy-security"
	_ "github.com/mholt/caddy-l4"
	_ "github.com/tailscale/caddy-tailscale"
)

func main() {
	caddycmd.Main()
}
