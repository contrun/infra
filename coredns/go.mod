module github.com/contrun/infra/coredns

go 1.16

replace github.com/coredns/coredns => github.com/mandelsoft/coredns v1.8.2-0.20210316124450-bb3e135606d8

require (
	github.com/coredns/alternate v0.0.0-20201105225029-f0d10f2aa3aa
	github.com/coredns/coredns v1.8.2
	github.com/openshift/coredns-mdns v0.0.0-20210225112255-5f49dc40907c
)
