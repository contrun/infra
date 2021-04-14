package main

import (
	caddycmd "github.com/caddyserver/caddy/v2/cmd"

	// plug in Caddy modules here
	_ "github.com/caddyserver/caddy/v2/modules/standard"
	_ "github.com/mholt/caddy-l4"
	_ "github.com/greenpau/caddy-auth-jwt"
	_ "github.com/greenpau/caddy-auth-portal"
	_ "github.com/mastercactapus/caddy2-proxyprotocol"
)

func main() {
	caddycmd.Main()
}
