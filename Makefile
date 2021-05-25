.DEFAULT_GOAL := home-install
.PHONY: $(shell sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' $(MAKEFILE_LIST))

DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
ROOTDIR = $(DIR)/root
IGNOREDDIR = $(DIR)/ignored
HOST ?= $(shell hostname)
DESTDIR ?= ${HOME}
DESTROOTDIR ?= /
# The chezmoi state directory is stored in the same directory as the config file,
# which may not be writable.
CHEZMOIFLAGS := -v $(if $(findstring /nix/store/,$(DIR)),,-c $(IGNOREDDIR)/chezmoi.toml)

CHEZMOI.home = chezmoi
CHEZMOI.root = sudo chezmoi
DESTDIR.home = $(DESTDIR)
DESTDIR.root = $(DESTROOTDIR)
SRCDIR.home = $(DIR)
SRCDIR.root = $(ROOTDIR)
NIXOSREBUILD.build = nix build .\#nixosConfigurations.$(HOST).config.system.build.toplevel
NIXOSREBUILD.switch = sudo nixos-rebuild switch --flake .\#$(HOST) $(if $(findstring -dirty,$1),,--profile-name flake.$(shell date +%Y%m%d).$(shell git rev-parse --short HEAD))
NIXOSREBUILD.bootloader = $(NIXOS.switch) --install-bootloader
EXTRANIXFLAGS = $(if $(SYSTEM),--system $(SYSTEM) --extra-extra-platforms $(SYSTEM),)
NIXFLAGS = $(EXTRANIXFLAGS) --show-trace --keep-going --keep-failed
target = $(firstword $(subst -, ,$1))
script = $(firstword $(subst -, ,$1))
action = $(word 2,$(subst -, ,$1))
chezmoi = ${CHEZMOI.$(firstword $(subst -, ,$1))} ${CHEZMOIFLAGS}
dest = $(DESTDIR.$(firstword $(subst -, ,$1)))
src = $(SRCDIR.$(firstword $(subst -, ,$1)))
nixos-rebuild = $(NIXOSREBUILD.$(word 2,$(subst -, ,$1)))

pull:
	git pull --rebase --autostash

push:
	git status
	git commit -a -m "auto push at $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')"
	git log HEAD^..HEAD
	git diff HEAD^..HEAD
	read -p 'Press enter to continue, C-c to exit' && git push

autopush:
	git commit -a -m "auto push at $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')"
	git push

upload: pull push

update: pull update-upstreams deps-install install

update-upstreams:
	nix flake update

remove-build-artifacts:
	if [[ "$(realpath result)" == /nix/store/* ]]; then rm -f result; fi

home-install: remove-build-artifacts
	[[ -f $(DESTDIR)/.config/Code/User/settings.json ]] || install -DT $(DIR)/dot_config/Code/User/settings.json $(DESTDIR)/.config/Code/User/settings.json
	diff $(DESTDIR)/.config/Code/User/settings.json $(DIR)/dot_config/Code/User/settings.json || nvim -d $(DESTDIR)/.config/Code/User/settings.json $(DIR)/dot_config/Code/User/settings.json
	$(call chezmoi,$@) -D $(call dest,$@) -S $(call src,$@) apply --keep-going || true

root-install: remove-build-artifacts
	$(call chezmoi,$@) -D $(call dest,$@) -S $(call src,$@) apply --keep-going || true

install: home-install root-install

deps-install deps-uninstall deps-reinstall:
	test -f "$(IGNOREDDIR)/$(call script,$@).sh" && DESTDIR=$(DESTDIR) "$(IGNOREDDIR)/$(call script,$@).sh" "$(call action,$@)" || true

all-install: home-install deps-install root-install

home-uninstall root-uninstall: remove-build-artifacts
	$(call chezmoi,$@) -D $(call dest,$@) -S $(call src,$@) purge

uninstall: deps-uninstall home-uninstall root-uninstall

home-manager: home-install
	home-manager switch -v --keep-going --keep-failed

nixos-build-dirty nixos-switch-dirty nixos-bootloader-dirty:
	$(call nixos-rebuild,$@) ${NIXFLAGS}

nixos-build nixos-switch nixos-bootloader:
	if git diff --exit-code; then $(call nixos-rebuild,$@) ${NIXFLAGS}; else (git stash; $(call nixos-rebuild,$@) ${NIXFLAGS}; git stash pop;); fi

# Filters do not work yet, as cachix will upload the closure.
cachix-push:
	if ! make HOST=$(HOST) -C ${DIR} nixos-build-dirty; then :; fi
	nix show-derivation -r .#nixosConfigurations.$(HOST).config.system.build.toplevel | jq -r '.[].outputs[].path' | xargs -i sh -c 'test -f "{}" && echo "{}"' | grep -vE 'clion|webstorm|idea-ultimate|goland|pycharm-professional|datagrip|android-studio-dev|graalvm11-ce|lock$$|-source$$' | cachix push contrun

cachix-push-all:
	make HOST=cicd-x86_64-linux -C ${DIR} cachix-push
	make HOST=cicd-aarch64-linux -C ${DIR} cachix-push

nixos-update-channels:
	sudo nix-channel --update
