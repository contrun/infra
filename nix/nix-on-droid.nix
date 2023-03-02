{ pkgs, lib, config, ... }:
let
  sshdTmpDirectory = "${config.user.home}/.sshd-tmp";
  sshdDirectory = "${config.user.home}/.sshd";
  dotfilesDirectory = "${config.user.home}/.local/share/chezmoi";
  dotfilesRepo = "https://github.com/contrun/dotfiles";
  githubUser = "contrun";
  port = 8822;
in
{
  build.activation.sshd = ''
    $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${config.user.home}/.ssh"
    if [[ ! -f "${config.user.home}/.ssh/authorized_keys" ]]; then
      # ssh-import-id requires ssh-keygen
      if ! PATH="${lib.makeBinPath [ pkgs.openssh ]}:$PATH" $DRY_RUN_CMD ${pkgs.ssh-import-id}/bin/ssh-import-id -o "${config.user.home}/.ssh/authorized_keys" "gh:${githubUser}"; then
        $VERBOSE_ECHO "Importing ssh key from ${githubUser} failed"
      fi
    fi

    if [[ ! -d "${sshdDirectory}" ]]; then
      $DRY_RUN_CMD rm $VERBOSE_ARG --recursive --force "${sshdTmpDirectory}"
      $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${sshdTmpDirectory}"

      $VERBOSE_ECHO "Generating host keys..."
      $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f "${sshdTmpDirectory}/ssh_host_rsa_key" -N ""

      $VERBOSE_ECHO "Writing sshd_config..."
      $DRY_RUN_CMD ${pkgs.python3}/bin/python -c 'with open("${sshdTmpDirectory}/sshd_config", "w") as f: f.write("HostKey ${sshdDirectory}/ssh_host_rsa_key\nPort ${toString port}\n")'

      $DRY_RUN_CMD mv $VERBOSE_ARG "${sshdTmpDirectory}" "${sshdDirectory}"
    fi
  '';

  build.activation.dotfiles = ''
    if [[ ! -d "${dotfilesDirectory}" ]]; then
      $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${dotfilesDirectory}"
      if ! $DRY_RUN_CMD ${pkgs.git}/bin/git clone "${dotfilesRepo}" "${dotfilesDirectory}"; then
        $VERBOSE_ECHO "Cloning repo ${dotfilesRepo} into ${dotfilesDirectory} failed"
      fi
      if ! PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.diffutils pkgs.gnupg pkgs.gnugrep pkgs.gnused pkgs.curl pkgs.chezmoi pkgs.git ]}:$PATH" $DRY_RUN_CMD ${pkgs.gnumake}/bin/make -C "${dotfilesDirectory}" home-install; then
        $VERBOSE_ECHO "Installing dotfiles failed"
      fi
    fi
  '';

  environment.packages = with pkgs; [
    git
    man
    openssh
    gnupg
    mosh
    coreutils
    rsync
    diffutils
    gnugrep
    gnused
    gawk
    curl
    neovim
    chezmoi
    gnumake
    (writeShellApplication {
      name = "sshd-start";
      text = ''
        ip -brief addr show scope global up
        echo "Starting sshd on port ${toString port}"
        # sshd re-exec requires execution with an absolute path
        exec ${pkgs.openssh}/bin/sshd -f "${sshdDirectory}/sshd_config" -D "$@"
      '';
      runtimeInputs = with pkgs; [ iproute2 openssh ];
    })
    self.packages."aarch64-linux".mosha
    self.packages."aarch64-linux".ssha
  ];
  system.stateVersion = "22.05";
}
