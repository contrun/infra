.DEFAULT_GOAL := nixos-deploy
.PHONY: $(shell sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' $(MAKEFILE_LIST))

POUND := \#

HOST ?= $(shell hostname)
HOME ?= $(HOMEDRIVE)$(HOMEPATH)
USER ?= $(USERNAME)

EXTRANIXFLAGS ?=
NIXFLAGS = $(strip $(strip $(if $(SYSTEM),--system $(SYSTEM) --extra-extra-platforms $(SYSTEM),) --impure --show-trace --keep-going --print-build-logs) $(EXTRANIXFLAGS))

# Adding `|| true` because https://stackoverflow.com/questions/12989869/calling-command-v-find-from-gnu-makefile
DEPLOY ?= $(if $(shell command -v deploy || true),deploy,nix run ".$(POUND)deploy-rs" --)
HOMEMANAGER ?= $(if $(shell command -v home-manager || true),home-manager,nix run ".$(POUND)home-manager" --)
NOROLLBACK ?=
NOFASTCONNECTION ?=
EXTRADEPLOYFLAGS ?=
DEPLOYFLAGS ?= $(strip $(strip $(strip --skip-checks --debug-logs $(if $(NOROLLBACK),--auto-rollback=false --magic-rollback=false,)) $(if $(NOFASTCONNECTION),--fast-connection=false,)) $(EXTRADEPLOYFLAGS))
GENERATE ?= $(if $(shell command -v nixos-generate || true),nixos-generate,nix run ".$(POUND)nixos-generate" --)
GENERATEFORMAT ?= iso
# To build a vm with command `make nixos-build BUILDTYPE=vmWithBootLoader`
BUILDTYPE ?= toplevel

NIXOSREBUILD.build = nix build ".$(POUND)nixosConfigurations.$(HOST).config.system.build.$(BUILDTYPE)"
NIXOSREBUILD.switch = sudo nixos-rebuild switch --flake ".$(POUND)$(HOST)"
NIXOSREBUILD.bootloader = $(NIXOSREBUILD.switch) --install-bootloader
nixos-rebuild = $(NIXOSREBUILD.$(word 2,$(subst -, ,$1)))

DIR := $(dir $(realpath $(firstword $(MAKEFILE_LIST))))
ROOTDIR = $(DIR)/root
IGNOREDDIR = $(DIR)/ignored
DESTDIR ?= $(HOME)
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
chezmoi = ${CHEZMOI.$(firstword $(subst -, ,$1))} ${CHEZMOIFLAGS}
dest = $(DESTDIR.$(firstword $(subst -, ,$1)))
src = $(SRCDIR.$(firstword $(subst -, ,$1)))

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

update: pull update-upstreams

chezmoi-init chezmoi-update chezmoi-status chezmoi-apply chezmoi-purge:
	$(CHEZMOI) $(CHEZMOIFLAGS) -D "$(DESTDIR)" -S "$(SRCDIR)" $(word 2,$(subst -, ,$@))

home-install root-install:
	$(call chezmoi,$@) -D "$(call dest,$@)" -S "$(call src,$@)" apply

all-install: home-install root-install

home-uninstall root-uninstall:
	$(call chezmoi,$@) -D $(call dest,$@) -S $(call src,$@) purge

all-uninstall: home-uninstall root-uninstall

update-upstreams:
	nix flake update

clean:
	[[ -d tmp ]] && rm -rf tmp/
	if [[ "$(realpath result)" == /nix/store/* ]]; then rm -f result; fi

sops:
	sops ./nix/sops/secrets.yaml

create-dirs:
	mkdir -p tmp

home-manager:
	$(HOMEMANAGER) switch --flake ".#$(USER)@$(HOST)" $(NIXFLAGS)

home-manager-build:
	$(HOMEMANAGER) build --flake ".#$(USER)@$(HOST)" $(NIXFLAGS)

home-manager-bootstrap:
	$(HOMEMANAGER) switch --flake ".#$(USER)@cicd-$(shell nix eval --raw --expr 'builtins.currentSystem')" $(NIXFLAGS)

nixos-prefs: JQ = $(or $(shell command -v jq),cat)
nixos-prefs: create-dirs
	nix eval --impure --raw --expr "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.$(HOST).config.passthru.prefsJson" | $(JQ) | tee tmp/prefs.$(HOST).json

nixos-deploy:
	$(DEPLOY) $(DEPLOYFLAGS) ".#$(HOST)" -- $(NIXFLAGS)

nixos-profile-path-info: create-dirs
	nix path-info -sShr "$(shell $(NIXOSREBUILD.build) $(NIXFLAGS) --print-out-paths)" | tee tmp/nixos-profile-path-info.$(HOST)
	sort -h -k2 < tmp/nixos-profile-path-info.$(HOST)
	sort -h -k3 < tmp/nixos-profile-path-info.$(HOST)

nixos-build nixos-switch nixos-bootloader:
	$(call nixos-rebuild,$@)$(if $(filter nixos-build,$@), --print-out-paths,) $(NIXFLAGS)

nixos-generate:
	$(GENERATE) -f $(GENERATEFORMAT) --flake ".#$(HOST)"

# Filters do not work yet, as cachix will upload the closure.
cachix-push: create-dirs
	if ! make HOST=$(HOST) nixos-build; then :; fi
	nix derivation show $(NIXFLAGS) -r ".#nixosConfigurations.$(HOST).config.system.build.toplevel" | jq -r '.[].outputs[].path' | xargs -i sh -c 'test -f "{}" && echo "{}"' > tmp/cachix-push.paths
	grep -vE 'clion|webstorm|idea-ultimate|goland|pycharm-professional|datagrip|android-studio-dev|graalvm11-ce|lock$$|-source$$|ndk-bundle|vivaldi|sources-android|commandlinetools-linux' tmp/cachix-push.paths | cachix push contrun -m zstd -c 16 -j 1

cachix-push-all:
	make HOST=cicd-x86_64-linux cachix-push
	make HOST=cicd-aarch64-linux cachix-push

nixos-update-channels:
	sudo nix-channel --update

nixos-vagrant-box:
	$(GENERATE) -f vagrant-virtualbox --flake ".#dbx"

ansible-requirements:
	cd ansible && ansible-galaxy collection install -p galaxy-collections -r requirements.yml && ansible-galaxy role install -p galaxy-roles -r requirements.yml

ansible-diff-inventory-hosts:
	cd ansible && diff <(git cat-file blob HEAD:ansible/inventory/hosts.yml | ansible-vault view -) <(ansible-vault view inventory/hosts.yml)

ansible-view-inventory-hosts:
	cd ansible && ansible-vault view inventory/hosts.yml

ansible-edit-inventory-hosts:
	cd ansible && ansible-vault edit inventory/hosts.yml

ansible-deploy:
	cd ansible && ansible-playbook services.yml --extra-vars services=$(SERVICES)

flyctl-deploy:
	flyctl deploy -c fly/$(SERVICE)/fly.toml 
