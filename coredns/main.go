package main

import (
	_ "github.com/openshift/coredns-mdns"
	_ "github.com/coredns/example"
	_ "github.com/coredns/coredns/plugin/forward"
	_ "github.com/coredns/coredns/plugin/debug"
	_ "github.com/coredns/coredns/plugin/rewrite"
	_ "github.com/coredns/coredns/plugin/template"

	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/coremain"
)

var directives = []string{
	"mdns",
	"example",
	"debug",
	"forward",
	"rewrite",
	"template",
	"whoami",
	"startup",
	"shutdown",
}

func init() {
	dnsserver.Directives = directives
}

func main() {
	coremain.Run()
}
