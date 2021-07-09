package main

import (
	_ "github.com/coredns/alternate"
	_ "github.com/coredns/coredns/plugin/template"
	_ "github.com/coredns/coredns/plugin/log"
	_ "github.com/coredns/coredns/plugin/rewrite"
	_ "github.com/coredns/coredns/plugin/cancel"
	_ "github.com/coredns/coredns/plugin/whoami"
	_ "github.com/openshift/coredns-mdns"
	_ "github.com/epiclabs-io/epicmdns"

	"github.com/coredns/coredns/core/dnsserver"
	"github.com/coredns/coredns/coremain"
)

var directives = []string{
	"log",
	"debug",
	"template",
	"cancel",
	"rewrite",
	"mdns",
	"epicmdns",
	"alternate",
	"whoami",
	"startup",
	"shutdown",
	"reload",
	"forward",
}

func init() {
	dnsserver.Directives = directives
}

func main() {
	coremain.Run()
}
