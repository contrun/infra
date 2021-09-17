let
  pathOr = path: default: if (builtins.pathExists path) then path else default;
in { prefs, inputs }:
let
  inherit (prefs)
    hostname isMinimalSystem isVirtualMachine system getDotfile getNixConfig;

  moduleArgs = {
    inherit inputs hostname prefs isMinimalSystem isVirtualMachine system;
  };

  systemInfo = { lib, pkgs, config, ... }: {
    system.configurationRevision = lib.mkIf (inputs.self ? rev) inputs.self.rev;
    system.nixos.label = lib.mkIf (inputs.self.sourceInfo ? lastModifiedDate
      && inputs.self.sourceInfo ? shortRev) "flake.${
        builtins.substring 0 8 inputs.self.sourceInfo.lastModifiedDate
      }.${inputs.self.sourceInfo.shortRev}";
  };

  nixpkgsOverlay = { config, pkgs, system, inputs, ... }: {
    nixpkgs.overlays = [
      (self: super: {
        unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config = super.config;
        };
        stable = import inputs.nixpkgs-stable {
          inherit system;
          config = super.config;
        };
      })
    ];
  };

  hostConfiguration = { config, pkgs, ... }:
    {
      system.stateVersion = "20.09";
    } // (if hostname == "ssg" then {
      boot.loader.grub.devices =
        [ "/dev/disk/by-id/nvme-eui.00000000000000018ce38e03000f2dbe" ];
      services.xserver.videoDrivers = [ "amdgpu" ];
      hardware.cpu.amd.updateMicrocode = true;
    } else if hostname == "jxt" then {
      boot.loader.grub.devices =
        [ "/dev/disk/by-id/nvme-eui.002538a401b81628" ];
    } else if hostname == "shl" then
      { }
    else
      { });

  hardwareConfiguration = if isVirtualMachine then
    { config, lib, pkgs, modulesPath, ... }: { }
  else if isMinimalSystem then
    import
    (pathOr (getNixConfig "hardware/hardware-configuration.${hostname}.nix")
      (getNixConfig "hardware/hardware-configuration.example.nix"))
  else
    import
    (pathOr (getNixConfig "hardware/hardware-configuration.${hostname}.nix")
      /etc/nixos/hardware-configuration.nix);

  commonConfiguration = import (getNixConfig "common.nix");

  overlaysConfiguration = import (getNixConfig "overlays.nix");

  sopsConfiguration = { config, pkgs, lib, inputs, ... }:
    let
      sopsSecretsFile = getNixConfig "/sops/secrets.yaml";
      enableSops = builtins.pathExists sopsSecretsFile;
    in lib.optionalAttrs enableSops {
      sops = {
        validateSopsFiles = false;
        defaultSopsFile = "${builtins.path {
          name = "sops-secrets";
          path = sopsSecretsFile;
        }}";
        secrets = {
          clash-env = { };
          ddns-env = {
            mode = "0400";
            owner = prefs.owner;
            group = prefs.ownerGroup;
          };
          openldap-root-password = { };
          postgresql-env = { };
          postgresql-backup-env = { };
          postgresql-initdb-script = { mode = "0500"; };
          redis-conf = { mode = "0444"; };
          authelia-conf = { };
          authelia-users = { };
          etesync-env = { };
          vaultwarden-env = { };
          pleroma-env = { };
          joplin-env = { };
          miniflux-env = { };
          nextcloud-env = { };
          n8n-env = { };
          wikijs-env = { };
          xwiki-env = { };
          huginn-env = { };
          gitea-env = { };
          rss-bridge-whitelist = { mode = "0444"; };
          wallabag-env = { };
          recipes-env = { };
          wger-env = { };
          restic-password = { };
          rclone-config = { };
          yandex-passwd = {
            mode = "0400";
            owner = prefs.owner;
            group = prefs.ownerGroup;
          };
          cfssl-ca-pem = { mode = "0444"; };
        } // (lib.optionalAttrs prefs.enableAcme {
          acme-env = {
            mode = "0400";
            owner = "acme";
            group = "acme";
          };
        }) // (lib.optionalAttrs prefs.enablePostgresql {
          postgresql-init-script = {
            mode = "0440";
            owner = "postgres";
            group = "postgres";
          };
        }) // (lib.optionalAttrs prefs.enableAria2 {
          aria2-env = {
            mode = "0440";
            owner = "aria2";
            group = "aria2";
          };
        }) // (lib.optionalAttrs prefs.enableTraefik {
          traefik-env = {
            mode = "0400";
            owner = "traefik";
          };
        }) // (lib.optionalAttrs prefs.enablePrometheus {
          prometheus-env = {
            mode = "0400";
            owner = "prometheus";
          };
        }) // (lib.optionalAttrs
          (prefs.enablePrometheus && prefs.ociContainers.enablePostgresql) {
            prometheus-postgres-env = {
              mode = "0400";
              owner = "postgres-exporter";
            };
          }) // (lib.optionalAttrs (prefs.enableGrafana) {
            grafana-env = {
              mode = "0400";
              owner = "grafana";
            };
          }) // (lib.optionalAttrs prefs.enablePromtail {
            promtail-env = {
              mode = "0400";
              owner = "promtail";
              group = "promtail";
            };
          }) // (lib.optionalAttrs prefs.enableSmos {
            smos-sync-env = {
              mode = "0400";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
          }) // (lib.optionalAttrs prefs.enableCfssl {
            cfssl-ca-key-pem = { owner = "cfssl"; };
          }) // (lib.optionalAttrs prefs.enableGlusterfs {
            glusterfs-cert = { };
            glusterfs-cert-key = { };
          });
      };
    };

  homeManagerConfiguration = { config, pkgs, lib, inputs, ... }@args: {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users = {
        ${prefs.owner} = {
          _module.args = moduleArgs;
          imports = [
            (getNixConfig "/home.nix")
            ({ config, pkgs, lib, inputs, ... }@args: {
              home = {
                activation = {
                  chezmoi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                    oldstate=$(set +o)
                    set -x +e
                    if ! [[ -f ~/.dotfiles-initialized ]]; then
                        PATH="${
                          lib.makeBinPath [ pkgs.chezmoi pkgs.git pkgs.curl ]
                        }:$PATH" $DRY_RUN_CMD make --keep-going -C ${inputs.self} home-install deps-install
                    fi
                    eval "$oldstate"
                  '';
                };
              };
            })
          ] ++ (lib.optionals prefs.enableSmos
            [ (inputs.smos + "/nix/home-manager-module.nix") ]);
        };
      };
    };
  };

  vmConfiguration = hostname:
    let
      vmConfigs = {
        bigvm = {
          module = { config, lib, pkgs, modulesPath, ... }: {
            fileSystems."/" = {
              label = "nixos";
              fsType = "ext4";
              autoResize = true;
            };

            swapDevices = [ ];

            nix.maxJobs = lib.mkDefault 8;
          };
          imageSize = "50G";
        };
      };
      vmConfig = vmConfigs."${hostname}" or null;
    in { config, pkgs, lib, ... }:
    with pkgs;
    if vmConfig != null then
      let
        toplevel = config.system.build.toplevel;
        db = closureInfo { rootPaths = [ toplevel ]; };
        rootfs = config.fileSystems."/";

        # TMPDIR="$PWD/tmp" $(nix build '.#nixosConfigurations.bigvm.config.system.build.mkImageScript' --json | jq -r '.[].outputs.out')
        mkImageScript = pkgs.writeShellScript "nixos-image-builder" ''
          set -xeu
          export TERM=dumb
          export HOME="$TMPDIR/home"
          export ROOT="$TMPDIR/root"
          export NIX_STATE_DIR="$TMPDIR/state"
          export OUT_IMAGE="''${OUT_IMAGE:-$TMPDIR/nixos.img}"
          ${nix}/bin/nix-store --load-db < ${db}/registration
          ${nix}/bin/nix copy --no-check-sigs --to "$ROOT" ${toplevel}
          ${nix}/bin/nix-env --store "$ROOT" -p "$ROOT/nix/var/nix/profiles/system" --set ${toplevel}
          ${fakeroot}/bin/fakeroot ${libguestfs-with-appliance}/bin/guestfish -vx -N "$OUT_IMAGE=fs:${rootfs.fsType}:${vmConfig.imageSize}" -m /dev/sda1 << EOT
          set-label /dev/sda1 ${rootfs.label}
          copy-in "$ROOT/nix" /
          mkdir-mode /etc 0755
          command "/nix/var/nix/profiles/system/activate"
          command "/nix/var/nix/profiles/system/bin/switch-to-configuration boot"
          EOT
        '';
      in {
        imports = [ vmConfig.module ];
        boot.loader.grub.device = lib.mkForce "/dev/sda";

        # nix build '.#nixosConfigurations.bigvm.config.system.build.mkImage'
        system.build.image = runCommandNoCC "nixos.img" { } ''
          OUT_IMAGE="$out" ${mkImageScript}
        '';

        system.build.mkImageScript = mkImageScript;
      }
    else
      { };

  miscConfiguration = { config, pkgs, system, inputs, ... }:
    let
      nixos-vscode-server = {
        imports = [ (import inputs.nixos-vscode-server) ];
        services.vscode-server.enable = true;
      };
    in nixos-vscode-server;

  tmpConfiguration = { config, pkgs, system, inputs, ... }: { };

in {
  "${hostname}" = inputs.nixpkgs.lib.nixosSystem {
    inherit system;

    modules = [
      systemInfo
      nixpkgsOverlay
      hostConfiguration
      hardwareConfiguration
      commonConfiguration
      inputs.nixpkgs.nixosModules.notDetected
      inputs.sops-nix.nixosModules.sops
      sopsConfiguration
      inputs.home-manager.nixosModules.home-manager
      homeManagerConfiguration
      overlaysConfiguration
      miscConfiguration
      tmpConfiguration
      (vmConfiguration hostname)
    ];

    specialArgs = moduleArgs;
  };
}
