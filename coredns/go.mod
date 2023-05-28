module github.com/contrun/infra/coredns

go 1.16

replace github.com/coredns/coredns => github.com/mandelsoft/coredns v1.8.2-0.20210316124450-bb3e135606d8

require (
	github.com/coredns/alternate v0.0.0-20201105225029-f0d10f2aa3aa
	github.com/coredns/coredns v1.8.4
	github.com/epiclabs-io/epicmdns v0.0.0-20210308225500-1dbb05ab7fcd
	github.com/openshift/coredns-mdns v0.0.0-20210625150643-8c0b6474833f
	github.com/sirupsen/logrus v1.7.0 // indirect
)
