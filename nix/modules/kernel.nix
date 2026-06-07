{
  config,
  pkgs,
  options,
  ...
}:
let
  cfg = config.prefs.kernel;
  overrideOptionWithDefault =
    option: default:
    option
    // {
      inherit default;
    };
in
{
  options.prefs.kernel = {
    packages = overrideOptionWithDefault options.boot.kernelPackages pkgs.linuxPackages_latest;
    modules = overrideOptionWithDefault options.boot.kernelModules [
      # For the sysctl net.bridge.bridge-nf-call-* options to work
      "br_netfilter"
    ];
    sysctl = overrideOptionWithDefault options.boot.kernel.sysctl {
      "fs.file-max" = 131071;
      "net.core.rmem_max" = 67108864;
      "net.core.wmem_max" = 67108864;
      "net.core.netdev_max_backlog" = 250000;
      "net.core.somaxconn" = 4096;
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.tcp_tw_reuse" = 1;
      "net.ipv4.tcp_fin_timeout" = 30;
      "net.ipv4.tcp_keepalive_time" = 1200;
      "net.ipv4.ip_local_port_range" = "10000 65000";
      "net.ipv4.tcp_max_syn_backlog" = 8192;
      "net.ipv4.tcp_max_tw_buckets" = 5000;
      "net.ipv4.tcp_fastopen" = 3;
      "net.ipv4.tcp_mem" = "25600 51200 102400";
      "net.ipv4.tcp_rmem" = "4096 87380 67108864";
      "net.ipv4.tcp_wmem" = "4096 65536 67108864";
      "net.ipv4.tcp_mtu_probing" = 1;
      "net.ipv4.tcp_congestion_control" = "bbr";
      # https://github.com/springzfx/cgproxy/blob/aaa628a76b2911018fc93b2e3276c177e85e0861/readme.md#known-issues
      # Transparent proxy does not work with these options on.
      # See also https://linuxconfig.org/how-to-use-bridged-networking-with-libvirt-and-kvm
      # See also https://wiki.libvirt.org/page/Net.bridge.bridge-nf-call_and_sysctl.conf
      "net.bridge.bridge-nf-call-arptables" = 0;
      "net.bridge.bridge-nf-call-ip6tables" = 0;
      "net.bridge.bridge-nf-call-iptables" = 0;
      "vfs.usermount" = 1;
      "net.ipv4.igmp_max_memberships" = 256;
      "fs.inotify.max_user_instances" = 256;
      "fs.inotify.max_user_watches" = 524288;
      "kernel.kptr_restrict" = 0;
      "kernel.perf_event_paranoid" = 1;
      "net.ipv4.conf.all.route_localnet" = 1;
      "net.ipv4.conf.default.route_localnet" = 1;
    };
    params = overrideOptionWithDefault options.boot.kernelParams [ "boot.shell_on_fail" ];
    initrdModules = overrideOptionWithDefault options.boot.initrd.kernelModules [
      "usbnet"
      "cdc_ether"
      "rndis_host"
    ];
  };

  config = {
    boot = {
      kernel = {
        inherit (cfg)
          sysctl
          ;
      };

      initrd = {
        kernelModules = cfg.initrdModules;
      };
      kernelParams = cfg.params;
      kernelModules = cfg.modules;
      kernelPackages = cfg.packages;
    };
  };
}
