.DEFAULT_GOAL := home-install
.PHONY: $(shell sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' $(MAKEFILE_LIST))

DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
ROOTDIR = $(DIR)/root
IGNOREDDIR = $(DIR)/ignored
HOST ?= $(shell hostname)
DESTDIR ?= ${HOME}
DESTROOTDIR ?= /
VERBOSE ?=
# The chezmoi state directory is stored in the same directory as the config file,
# which may not be writable.
CHEZMOIFLAGS ?= $(strip $(if $(VERBOSE),-v) --keep-going)

CHEZMOI = chezmoi
CHEZMOI.home = chezmoi
CHEZMOI.root = sudo chezmoi
DESTDIR.home = $(DESTDIR)
DESTDIR.root = $(DESTROOTDIR)
SRCDIR = $(DIR)
SRCDIR.home = $(SRCDIR)
SRCDIR.root = $(ROOTDIR)
target = $(firstword $(subst -, ,$1))
script = $(firstword $(subst -, ,$1))
action = $(word 2,$(subst -, ,$1))
chezmoi = ${CHEZMOI.$(firstword $(subst -, ,$1))} ${CHEZMOIFLAGS}
dest = $(DESTDIR.$(firstword $(subst -, ,$1)))
src = $(SRCDIR.$(firstword $(subst -, ,$1)))

push:
	git status
	git commit -a -m "auto push at $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')"
	git log HEAD^..HEAD
	git diff HEAD^..HEAD
	read -p 'Press enter to continue, C-c to exit' && git push

autopush:
	git commit -a -m "auto push at $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')"
	git push

init update status apply purge:
	$(CHEZMOI) $(CHEZMOIFLAGS) -D $(DESTDIR) -S $(SRCDIR) $@ || true

home-install root-install:
	$(call chezmoi,$@) -D $(call dest,$@) -S $(call src,$@) apply || true

all-install: home-install root-install

home-uninstall root-uninstall:
	$(call chezmoi,$@) -D $(call dest,$@) -S $(call src,$@) purge

all-uninstall: home-uninstall root-uninstall
