let
  pathOr = path: default: if (builtins.pathExists path) then path else default;
in
{
  self,
  hostname,
  prefs,
  inputs,
  nixpkgsConfig,
}:
let
  nixpkgs = inputs.nixpkgs;

  inherit (prefs)
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

  nixpkgsConfiguration =
    {
      config,
      pkgs,
      system,
      inputs,
      ...
    }:
    {
      nixpkgs.overlays = inputs.self.overlayList;
      nixpkgs.config = nixpkgsConfig;
    };

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
        secrets = {
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
        }
        //
          builtins.foldl'
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
                enable = prefs.enablePromtail;
                config = {
                  promtail-env = {
                    mode = "0400";
                    owner = "promtail";
                    group = "promtail";
                  };
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
            imports = [
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
            ];
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
      nixpkgsConfiguration
      hostConfiguration
      hardwareConfiguration
      commonConfiguration
      inputs.nixpkgs.nixosModules.notDetected
      inputs.sops-nix.nixosModules.sops
      sopsConfiguration
      microvmHostConfiguration
      microvmGuestConfiguration
      inputs.home-manager.nixosModules.home-manager
      miscConfiguration
      tmpConfiguration
      (vmConfiguration hostname)
    ]
    ++ (readModulesDir ./modules)
    ++ (
      let
        path = ./hosts + "/${hostname}.nix";
      in
      if (builtins.pathExists path) then [ path ] else [ ]
    );

    specialArgs = moduleArgs;
  };
}
