.DEFAULT_GOAL := nixos-deploy
.PHONY: $(shell sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' $(MAKEFILE_LIST))

HOST ?= $(shell hostname)

# TODO: Remove impure
# error: attribute 'currentSystem' missing https://github.com/obsidiansystems/obelisk/issues/854
NIXFLAGS = $(strip $(if $(SYSTEM),--system $(SYSTEM) --extra-extra-platforms $(SYSTEM),) --impure --show-trace --keep-going --keep-failed)

NIX_RUN_DEPLOY = nix run ".\#deploy-rs" --
# Some makefile quirks for the `#`, don't use `nix run ".\#deploy-rs" --` below.
DEPLOY ?= $(if $(shell command -v deploy),deploy,$(NIX_RUN_DEPLOY))
EXTRADEPLOYFLAGS ?=
DEPLOYFLAGS ?= $(strip --skip-checks --debug-logs --keep-result $(EXTRADEPLOYFLAGS))

NIXOSREBUILD.build = nix build ".\#nixosConfigurations.$(HOST).config.system.build.toplevel"
NIXOSREBUILD.switch = $(strip sudo nixos-rebuild switch --flake ".#$(HOST)" $(if $(shell git diff --quiet --exit-code && echo repo_clean),--profile-name flake.$(shell date +%Y%m%d).$(shell git rev-parse --short HEAD),))
NIXOSREBUILD.bootloader = $(NIXOSREBUILD.switch) --install-bootloader
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

update: pull update-upstreams

update-upstreams:
	nix flake update

clean:
	rm nixos-profile-path-info.*
	[[ -d tmp ]] && sudo rm -rf tmp/
	if [[ "$(realpath result)" == /nix/store/* ]]; then rm -f result; fi

nixos-deploy:
	$(DEPLOY) $(DEPLOYFLAGS) ".#$(HOST)" -- $(NIXFLAGS)

nixos-profile-path-info:
	nix path-info $(NIXFLAGS) -sShr ".#nixosConfigurations.$(HOST).config.system.build.toplevel" > nixos-profile-path-info.$(HOST)
	sort -h -k2 < nixos-profile-path-info.$(HOST)
	sort -h -k3 < nixos-profile-path-info.$(HOST)

nixos-build nixos-switch nixos-bootloader:
	$(call nixos-rebuild,$@) $(NIXFLAGS)

# Filters do not work yet, as cachix will upload the closure.
cachix-push:
	if ! make HOST=$(HOST) nixos-build; then :; fi
	nix show-derivation $(NIXFLAGS) -r ".#nixosConfigurations.$(HOST).config.system.build.toplevel" | jq -r '.[].outputs[].path' | xargs -i sh -c 'test -f "{}" && echo "{}"' | grep -vE 'clion|webstorm|idea-ultimate|goland|pycharm-professional|datagrip|android-studio-dev|graalvm11-ce|lock$$|-source$$' | cachix push contrun

cachix-push-all:
	make HOST=cicd-x86_64-linux cachix-push
	make HOST=cicd-aarch64-linux cachix-push

nixos-update-channels:
	sudo nix-channel --update
