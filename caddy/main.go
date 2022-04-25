package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	// plug in Caddy modules here
	_ "github.com/caddyserver/caddy/v2/modules/standard"
	_ "github.com/greenpau/caddy-security"
	_ "github.com/lucaslorentz/caddy-docker-proxy/plugin"
	_ "github.com/mholt/caddy-l4"
)

func main() {
	caddycmd.Main()
}
