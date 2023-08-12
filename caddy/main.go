package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	// plug in Caddy modules here
	_ "github.com/greenpau/caddy-security"
	_ "github.com/mholt/caddy-l4"
)

func main() {
	caddycmd.Main()
}
