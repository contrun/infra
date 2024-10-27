;; This is an operating system configuration template
;; for a "desktop" setup with GNOME and Xfce where the
;; root partition is encrypted with LUKS.

(use-modules (gnu) (gnu packages) (gnu system nss) (guix store) (gnu system locale))
(use-service-modules base desktop ssh dbus docker xorg)
(use-package-modules certs gnome shells bash perl)

(define %my-base-services
  (modify-services %base-services
    (guix-service-type config =>
                       (guix-configuration
                         (inherit config)
                         (use-substitutes? #t)
                         (substitute-urls (cons "http://cc.yihuo.men"
                                                 %default-substitute-urls))
                         (extra-options '("--gc-keep-deraivations"
                                          "--gc-keep-outputs"))))))

(define %my-desktop-services
  (modify-services %desktop-services
    (slim-service-type config =>
                       (slim-configuration
                         (inherit config)
                         ; (startx (xorg-start-command
                         ;           #:xserver-arguments '("-listen" "tcp")))
                         ; (auto-login? #t)
                         (default-user "e")))))


(define zsh-bin-path
  #~(string-append #$zsh "/bin/zsh"))

(define %common-special-files
  `(("/usr/bin/env" ,(file-append coreutils "/bin/env"))
    ("/bin/bash" ,(file-append bash "/bin/bash"))
    ("/usr/bin/perl" ,(file-append perl "/bin/perl"))))

(operating-system
  (host-name "ura")
  (timezone "Asia/Shanghai")
  (locale "de_DE.utf8")
  (locale-definitions
    (list (locale-definition (source "en_US")
                            (name "en_US.utf8"))
          (locale-definition (source "fr_FR")
                             (name "fr_FR.utf8"))
          (locale-definition (source "zh_CN")
                             (name "zh_CN.utf8"))))

  ;; Use the UEFI variant of GRUB with the EFI System
  ;; Partition mounted on /boot/efi.
  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (target "/boot/efi")))

  ;; Specify a mapped device for the encrypted root partition.
  ;; The UUID is that returned by 'cryptsetup luksUUID'.
  (mapped-devices
   (list (mapped-device
          (source (uuid "1ddb0c10-bee8-465a-b902-02f1e4bd6dbf"))
          (target "my-root")
          (type luks-device-mapping))))

  (file-systems (cons* (file-system
                        (device (file-system-label "my-root"))
                        (mount-point "/")
                        (type "btrfs")
                        (dependencies mapped-devices))
                       (file-system
                         (device (uuid "5328-2131" 'fat))
                         (mount-point "/boot/efi")
                         (type "vfat"))
                      %base-file-systems))
  (sudoers-file (plain-file "sudoers"
                            (string-append "root ALL=(ALL) ALL\n"
                                           "%wheel ALL=(ALL) ALL\n"
                                           "e ALL=(ALL) NOPASSWD: ALL\n")))

  (users (cons (user-account
                (name "e")
                (shell "/run/current-system/profile/bin/zsh")
                (comment "Yi")
                (group "users")
                (supplementary-groups '("wheel" "netdev"
                                        ;; "adbusers"
                                        "disk" "kvm" "docker"
                                        "tty"
                                        "audio" "video"))
                (home-directory "/home/e"))
               %base-user-accounts))

  ;; This is where we specify system-wide packages.
  (packages (append (map specification->package
                         '("tcpdump" "htop" "gnupg" "nss-certs"
                           "neovim" "zsh" "emacs" "git" "iptables"
                           "atool" "iw" "btrfs-progs" "rofi"
                           "pulseaudio" "bluez" "xrandr" "htop"
                           "cryptsetup" "mc" "ncdu" "ranger"
                           "python" "arandr" "pavucontrol"
                           "openssh" "snap" "rxvt-unicode"
                           ;; "xmonad" "xmobar"
                           "lua" "neomutt" "gptfdisk"
                           "tree" "which" "htop" "termite"
                           "nix" "gnutls" "i3-wm" "i3blocks"
                           "xcape" "perl" "xinput" "xrdb"
                           "tmux" "gvfs" "curl" "wget"))
                   %base-packages))

  ;; Add GNOME and/or Xfce---we can choose at the log-in
  ;; screen with F1.  Use the "desktop" services, which
  ;; include the X11 log-in service, networking with
  ;; NetworkManager, and more.
  (services (cons* (service special-files-service-type %common-special-files)
                   (service docker-service-type)
                   (console-keymap-service "/home/e/.local/share/kbd/keymaps/personal.map")
                   ; (gnome-desktop-service)
                   ; (xfce-desktop-service)
                   ;; (service dhcp-client-service-type)
                   ;; (ntp-service #:allow-large-adjustment? #t)
                   ;; (service docker-service-type)
                   (service openssh-service-type
                            (openssh-configuration
                              (x11-forwarding? #t)))
                   %my-desktop-services
                   ;;%my-base-services
))

  ;; Allow resolution of '.local' host names with mDNS.
  (name-service-switch %mdns-host-lookup-nss))
