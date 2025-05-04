let
  pathOr = path: default: if (builtins.pathExists path) then path else default;
in
{
  self,
  prefs,
  inputs,
}:
let
  nixpkgs = inputs.nixpkgs;

  inherit (prefs)
    hostname
    isMinimalSystem
    isMaximalSystem
    isVirtualMachine
    system
    getDotfile
    getNixConfig
    ;

  moduleArgs = {
    inherit
      inputs
      hostname
      prefs
      isMinimalSystem
      isMaximalSystem
      isVirtualMachine
      system
      ;
  };

  systemInfo =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    {
      system.configurationRevision = lib.mkIf (inputs.self ? rev) inputs.self.rev;
      system.stateVersion = prefs.systemStateVersion;
      system.nixos.label =
        lib.mkIf (inputs.self.sourceInfo ? lastModifiedDate && inputs.self.sourceInfo ? shortRev)
          "flake.${
            builtins.substring 0 8 inputs.self.sourceInfo.lastModifiedDate
          }.${inputs.self.sourceInfo.shortRev}";
    };

  nixpkgsOverlay =
    {
      config,
      pkgs,
      system,
      inputs,
      ...
    }:
    {
      nixpkgs.overlays = inputs.self.overlayList;
    };

  # Otherwise error: attribute 'androidSdk' missing
  # https://github.com/tadfisher/android-nixpkgs/issues/15
  androidlNixpkgsOverlay =
    {
      config,
      pkgs,
      system,
      inputs,
      ...
    }:
    if prefs.enableAndroidDevEnv then
      {
        nixpkgs.overlays = [ inputs.android-nixpkgs.overlays.default ];
      }
    else
      { };

  hostConfiguration =
    { config, pkgs, ... }:
    (
      if hostname == "ssg" then
        {
          boot.loader.grub.devices = [ "/dev/disk/by-id/nvme-eui.00000000000000018ce38e03000f2dbe" ];
          services.xserver.videoDrivers = [ "amdgpu" ];
          hardware.cpu.amd.updateMicrocode = true;
        }
      else if hostname == "jxt" then
        {
          boot.loader.grub.devices = [ "/dev/disk/by-id/nvme-eui.002538a401b81628" ];
        }
      else if hostname == "shl" then
        { }
      else if hostname == "aol" then
        {
          boot.loader.grub.devices = [
            "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b444a49fc6399"
            "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b4b8ff5da"
          ];
        }
      else if hostname == "dbx" then
        {
          virtualbox.memorySize = 2 * 1024;
        }
      else
        { }
    );

  hardwareConfiguration =
    if isVirtualMachine then
      {
        config,
        lib,
        pkgs,
        modulesPath,
        ...
      }:
      { }
    else if (isMinimalSystem || isMaximalSystem) then
      import (
        pathOr (getNixConfig "hardware/hardware-configuration.${hostname}.nix") (
          getNixConfig "hardware/hardware-configuration.example.nix"
        )
      )
    else
      import (
        pathOr (getNixConfig "hardware/hardware-configuration.${hostname}.nix") /etc/nixos/hardware-configuration.nix
      );

  commonConfiguration = import (getNixConfig "common.nix");

  microvmHostConfiguration =
    {
      config,
      pkgs,
      lib,
      inputs,
      ...
    }:
    lib.optionalAttrs prefs.enableMicrovmHost {
      imports = [ inputs.microvm.nixosModules.host ];
      microvm =
        let
          allVms = import (getNixConfig "microvms.nix") {
            inherit (inputs) microvm self;
            inherit system nixpkgs;
          };
        in
        {
          vms = lib.filterAttrs (name: vm: prefs.enabledMicroVmGuests ? "${name}") allVms;
        };
    };

  microvmGuestConfiguration =
    {
      config,
      pkgs,
      lib,
      inputs,
      ...
    }:
    lib.optionalAttrs prefs.enableMicrovmGuest {
      imports = [ inputs.microvm.nixosModules.microvm ];
      microvm = prefs.microvmGuestConfig;
    };

  sopsConfiguration =
    {
      config,
      pkgs,
      lib,
      inputs,
      ...
    }:
    let
      sopsSecretsFile = getNixConfig "/sops/secrets.yaml";
      enableSops = builtins.pathExists sopsSecretsFile;
    in
    lib.optionalAttrs enableSops {
      sops = {
        validateSopsFiles = false;
        defaultSopsFile = "${builtins.path {
          name = "sops-secrets";
          path = sopsSecretsFile;
        }}";
        secrets =
          {
            clash-env = { };
            ddns-env = {
              mode = "0400";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
            code-server-env = {
              mode = "0400";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
            "id_ed25519.pub" = {
              mode = "0400";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
            id_ed25519 = {
              mode = "0400";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
            keeweb-env = {
              mode = "0400";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
            openldap-root-password = { };
            vault-ssh-ca-setup-env = { };
            postgresql-env = { };
            postgresql-backup-env = { };
            postgresql-initdb-script = {
              mode = "0500";
            };
            redis-conf = {
              mode = "0444";
            };
            lldap-env = { };
            authelia-conf = { };
            authelia-users = { };
            authelia-local-users-conf = { };
            authelia-ldap-users-conf = { };
            authelia-sqlite-conf = { };
            authelia-postgres-conf = { };
            authelia-redis-conf = { };
            etesync-env = { };
            vaultwarden-env = { };
            pleroma-env = { };
            livebook-env = {
              mode = "0400";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
            joplin-env = { };
            miniflux-env = { };
            atuin-env = { };
            nextcloud-env = { };
            nextcloud-sqlite-env = { };
            nextcloud-postgres-env = { };
            nextcloud-redis-env = { };
            n8n-env = { };
            wikijs-env = { };
            xwiki-env = { };
            huginn-env = { };
            wakapi-env = { };
            gitea-env = { };
            rss-bridge-whitelist = {
              mode = "0444";
            };
            wallabag-env = { };
            recipes-env = { };
            wger-env = { };
            bookwyrm-env = { };
            superset-env = { };
            superset-config = {
              mode = "0444";
            };
            restic-password = { };
            rclone-config = { };
            rclone-webui-htpasswd = { };
            initrd-hole-puncher = { };
            "port-forwarding-id_ed25519.pub" = {
              mode = "0444";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
            port-forwarding-id_ed25519 = {
              mode = "0400";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
            initrd_ssh_host_ed25519_key = { };
            "initrd_ssh_host_ed25519_key.pub" = { };
            yandex-passwd = {
              mode = "0400";
              owner = prefs.owner;
              group = prefs.ownerGroup;
            };
            cfssl-ca-pem = {
              mode = "0444";
            };
          }
          // builtins.foldl'
            (
              acc: e:
              let
                go = e: if e.enable or true then e.config else { };
              in
              acc // go e
            )
            { }
            [
              {
                enable = prefs.enableWireguard;
                config = {
                  wireguard-post-up = {
                    mode = "0550";
                  };
                  "wireguard-private-key-${builtins.toString prefs.wireguardHostIndex}" = {
                    mode = "0400";
                    path = "/run/wireguard-private-key";
                  };
                };
              }
              {
                enable = prefs.enableAcme;
                config = {
                  acme-env = {
                    mode = "0400";
                    owner = "acme";
                    group = "acme";
                  };
                };
              }
              {
                enable = prefs.enableAria2;
                config = {
                  aria2-rpc-secret = { };
                };
              }
              {
                enable = prefs.ociContainers.enableVault;
                config = {
                  vault-env = { };
                };
              }
              {
                enable = prefs.enablePostgresql;
                config = {
                  postgresql-init-script = {
                    mode = "0440";
                    owner = "postgres";
                    group = "postgres";
                  };
                };
              }
              {
                enable = prefs.enableAria2;
                config = {
                  aria2-env = {
                    mode = "0440";
                    owner = "aria2";
                    group = "aria2";
                  };
                };
              }
              {
                enable = prefs.enableTraefik;
                config = {
                  traefik-env = {
                    mode = "0400";
                    owner = "traefik";
                  };
                };
              }
              {
                enable = prefs.enablePrometheus;
                config = {
                  prometheus-env = {
                    mode = "0400";
                    owner = "prometheus";
                  };
                  prometheus-remote-write-password = {
                    mode = "0400";
                    owner = "prometheus";
                  };
                };
              }
              {
                enable = prefs.enablePrometheus && prefs.ociContainers.enablePostgresql;
                config = {
                  prometheus-postgres-env = {
                    mode = "0400";
                    owner = "postgres-exporter";
                  };
                };
              }
              {
                enable = prefs.enableGrafana;
                config = {
                  grafana-env = {
                    mode = "0400";
                    owner = "grafana";
                  };
                };
              }
              {
                enable = prefs.enablePromtail;
                config = {
                  promtail-env = {
                    mode = "0400";
                    owner = "promtail";
                    group = "promtail";
                  };
                };
              }
              {
                enable = prefs.enableSmos;
                config = {
                  smos-sync-env = {
                    mode = "0400";
                    owner = prefs.owner;
                    group = prefs.ownerGroup;
                  };
                };
              }
              {
                enable = prefs.enableCfssl;
                config = {
                  cfssl-ca-key-pem = {
                    owner = "cfssl";
                  };
                };
              }
              {
                enable = prefs.enableGlusterfs;
                config = {
                  glusterfs-cert = { };
                  glusterfs-cert-key = { };
                };
              }
            ];
      };
    };

  homeManagerConfiguration =
    {
      config,
      pkgs,
      lib,
      inputs,
      ...
    }@args:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        users = {
          ${prefs.owner} = {
            _module.args = moduleArgs;
            imports =
              [
                (getNixConfig "/home.nix")
                (
                  {
                    config,
                    pkgs,
                    lib,
                    inputs,
                    ...
                  }@args:
                  {
                    home = {
                      activation = {
                        chezmoi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                          oldstate=$(set +o)
                          set -x +e
                          if ! [[ -f ~/.dotfiles-initialized ]]; then
                              PATH="${
                                lib.makeBinPath [
                                  pkgs.chezmoi
                                  pkgs.git
                                  pkgs.curl
                                ]
                              }:$PATH" $DRY_RUN_CMD make --keep-going -C ${inputs.self} home-install deps-install
                          fi
                          eval "$oldstate"
                        '';
                      };
                    };
                  }
                )
              ]
              ++ (lib.optionals prefs.enableAndroidDevEnv [
                inputs.android-nixpkgs.hmModule
                {
                  home.packages = with pkgs; [
                    android-studio
                    flutter
                  ];
                  android-sdk.enable = true;
                  android-sdk.packages =
                    sdkPkgs:
                    with sdkPkgs;
                    [
                      build-tools-34-0-0
                      cmdline-tools-latest
                      ndk-bundle
                      emulator
                      platform-tools
                      tools
                      platforms-android-34
                      sources-android-34
                      cmake-3-22-1
                    ]
                    ++ (
                      if prefs.nixosSystem == "x86_64-linux" then
                        [
                          system-images-android-34-default-x86-64
                        ]
                      else
                        [ ]
                    );
                }
              ])
              ++ (lib.optionals prefs.enableSmos [ (inputs.smos + "/nix/home-manager-module.nix") ]);
          };
        };
      };
    };

  vmConfiguration =
    hostname:
    let
      vmConfigs = {
        bigvm = {
          module =
            {
              config,
              lib,
              pkgs,
              modulesPath,
              ...
            }:
            {
              fileSystems."/" = {
                label = "nixos";
                fsType = "ext4";
                autoResize = true;
              };

              swapDevices = [ ];

              nix.settings.max-jobs = lib.mkDefault 8;
            };
          imageSize = "50G";
        };
      };
      vmConfig = vmConfigs."${hostname}" or null;
    in
    {
      config,
      pkgs,
      lib,
      ...
    }:
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
      in
      {
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

  readModulesDir =
    path:
    builtins.map (x: path + "/${x}") (
      builtins.filter (str: (builtins.match "^[^.]*(\.nix)?$" str) != null) (
        builtins.attrNames (builtins.readDir path)
      )
    );

  miscConfiguration =
    {
      config,
      pkgs,
      system,
      inputs,
      ...
    }:
    let
      nixos-vscode-server = {
        imports = [ (import inputs.nixos-vscode-server) ];
        services.vscode-server.enable = true;
      };
    in
    nixos-vscode-server;

  tmpConfiguration =
    {
      config,
      pkgs,
      system,
      inputs,
      ...
    }:
    { };

in
{
  # TODO: Remove makeOverridable.
  # Workaround for `nixos-generate --flake`, see https://github.com/nix-community/nixos-generators/issues/110
  "${hostname}" = (with inputs.nixpkgs.lib; makeOverridable nixosSystem) {
    inherit system;

    modules = [
      systemInfo
      nixpkgsOverlay
      androidlNixpkgsOverlay
      hostConfiguration
      hardwareConfiguration
      commonConfiguration
      inputs.nixpkgs.nixosModules.notDetected
      inputs.sops-nix.nixosModules.sops
      sopsConfiguration
      microvmHostConfiguration
      microvmGuestConfiguration
      inputs.home-manager.nixosModules.home-manager
      homeManagerConfiguration
      miscConfiguration
      tmpConfiguration
      (vmConfiguration hostname)
    ] ++ (readModulesDir (getNixConfig "modules"));

    specialArgs = moduleArgs;
  };
}
