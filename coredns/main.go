package main

import (
	_ "github.com/coredns/alternate"
	_ "github.com/coredns/coredns/plugin/template"
	_ "github.com/openshift/coredns-mdns"

	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/coremain"
)

var directives = []string{
	"template",
	"mdns",
	"alternate",
	"whoami",
	"startup",
	"shutdown",
	"reload",
}

func init() {
	dnsserver.Directives = directives
}

func main() {
	coremain.Run()
}
