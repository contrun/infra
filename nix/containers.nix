{ pkgs }:
{
  texlive =
    with pkgs;
    dockerTools.buildImage rec {
      name = "texlive-full";
      tag = "latest";
      copyToRoot = buildEnv {
        inherit name;
        paths = [
          (texlive.combine { inherit (texlive) scheme-full; })
          adoptopenjdk-bin
          font-awesome_4
          font-awesome_5
          nerdfonts
          pdftk
          bash
          gnugrep
          gnused
          coreutils
          gnumake
        ];
      };
      config.Cmd = [ "/bin/sh" ];
    };

  rclone =
    with pkgs;
    let
      rcdPort = 5572;
      rcdBaseUrl = "rclone";
      s3Port = 5573;
      s3BaseUrl = "s3";
      webdavPort = 5574;
      webdavBaseUrl = "webdav";
      httpPort = 5575;
      httpBaseUrl = "files";
      httpPublicPort = 5576;
      httpPublicBaseUrl = "public";
      envoyAdminPort = 9901;
      envoyPort = 10000;
      envoyConfig =
        let
          format = formats.json { };
          config =
            let
              mkRoute = baseUrl: serviceName: {
                match = {
                  prefix = "/${baseUrl}";
                };
                route = {
                  cluster = serviceName;
                };
              };
              mkCluster = name: port: {
                inherit name;
                connect_timeout = "0.25s";
                type = "STATIC";
                lb_policy = "ROUND_ROBIN";
                load_assignment = {
                  cluster_name = name;
                  endpoints = [
                    {
                      lb_endpoints = [
                        {
                          endpoint = {
                            address = {
                              socket_address = {
                                address = "127.0.0.1";
                                port_value = port;
                              };
                            };
                          };
                        }
                      ];
                    }
                  ];
                };
              };
              mkRouteAndCluster = name: url: port: {
                route = mkRoute url name;
                cluster = mkCluster name port;
              };
              routesAndClusters = builtins.map (x: mkRouteAndCluster x.name x.url x.port) [
                {
                  name = rcdBaseUrl;
                  url = rcdBaseUrl;
                  port = rcdPort;
                }
                {
                  name = s3BaseUrl;
                  url = s3BaseUrl;
                  port = s3Port;
                }
                {
                  name = webdavBaseUrl;
                  url = webdavBaseUrl;
                  port = webdavPort;
                }
                {
                  name = httpBaseUrl;
                  url = httpBaseUrl;
                  port = httpPort;
                }
                {
                  name = httpPublicBaseUrl;
                  url = httpPublicBaseUrl;
                  port = httpPublicPort;
                }
              ];
              routes = builtins.map (x: x.route) routesAndClusters;
              clusters = builtins.map (x: x.cluster) routesAndClusters;
            in
            {
              admin = {
                address = {
                  socket_address = {
                    address = "0.0.0.0";
                    port_value = envoyAdminPort;
                  };
                };
              };

              overload_manager = {
                resource_monitors = [
                  {
                    name = "envoy.resource_monitors.global_downstream_max_connections";
                    typed_config = {
                      "@type" =
                        "type.googleapis.com/envoy.extensions.resource_monitors.downstream_connections.v3.DownstreamConnectionsConfig";
                      max_active_downstream_connections = 50000;
                    };
                  }
                ];
              };

              static_resources = {
                listeners = [
                  {
                    name = "listener_0";
                    address = {
                      socket_address = {
                        address = "0.0.0.0";
                        port_value = envoyPort;
                      };
                    };
                    filter_chains = [
                      {
                        filters = [
                          {
                            name = "envoy.filters.network.http_connection_manager";
                            typed_config = {
                              "@type" =
                                "type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager";
                              stat_prefix = "ingress_http";
                              codec_type = "AUTO";
                              route_config = {
                                name = "local_route";
                                virtual_hosts = [
                                  {
                                    name = "local_service";
                                    domains = [ "*" ];
                                    inherit routes;
                                  }
                                ];
                              };
                              http_filters = [
                                {
                                  name = "envoy.filters.http.router";
                                  typed_config = {
                                    "@type" = "type.googleapis.com/envoy.extensions.filters.http.router.v3.Router";
                                  };
                                }
                              ];
                            };
                          }
                        ];
                      }
                    ];
                  }
                ];

                inherit clusters;
              };
            };
          configFile = format.generate "envoy.json" config;
          validateConfig =
            file:
            runCommand "validate-envoy-conf" { } ''
              ${envoy-bin}/bin/envoy --log-level error --mode validate -c "${file}"
              cp "${file}" "$out"
            '';
        in
        validateConfig configFile;
      getSecretName = "get-secret";
      getSecret = writeShellApplication {
        name = getSecretName;
        text = ''
          set -euo pipefail
          bws secret get "$1" | jq -r '.value'
        '';
        runtimeInputs = [
          bws
          jq
        ];
      };
      entrypointName = "container-entrypoint";
      entrypoint = writeShellApplication {
        name = entrypointName;
        text = ''
          set -euo pipefail
          export RCLONE_CONFIG="/tmp/rclone.conf"
          ${getSecretName} f9876fcd-2545-43d4-be09-b401012a679a > "$RCLONE_CONFIG"
          export RCLONE_PASSWORD_COMMAND="${getSecretName} 3b3ca859-97eb-486b-829b-b20a010a7747"
          rclone_user="$(${getSecretName} 4615a562-2a50-4a71-adc5-b4010124ddeb)"
          rclone_pass="$(${getSecretName} f360f175-7e38-4ac8-9e53-b40101250a36)"
          RCLONE_RC_USER="$rclone_user" RCLONE_RC_PASS="$rclone_pass" rclone rcd --cache-dir /data/cache --rc-addr :${builtins.toString rcdPort} --rc-baseurl ${rcdBaseUrl} --rc-web-gui --rc-web-gui-no-open-browser &
          curl --retry 20 --retry-delay 1 --retry-connrefused http://localhost:${builtins.toString rcdPort}/${rcdBaseUrl}
          rclone rc --user "$rclone_user" --pass "$rclone_pass" --url http://localhost:${builtins.toString rcdPort}/${rcdBaseUrl} serve/start type=s3 fs=root: addr=:${builtins.toString s3Port} baseurl=${s3BaseUrl} auth_key="$rclone_user,$rclone_pass"
          rclone rc --user "$rclone_user" --pass "$rclone_pass" --url http://localhost:${builtins.toString rcdPort}/${rcdBaseUrl} serve/start type=webdav fs=root: addr=:${builtins.toString webdavPort} baseurl=${webdavBaseUrl} realm=${webdavBaseUrl} user="$rclone_user" pass="$rclone_pass"
          rclone rc --user "$rclone_user" --pass "$rclone_pass" --url http://localhost:${builtins.toString rcdPort}/${rcdBaseUrl} serve/start type=http fs=root: addr=:${builtins.toString httpPort} baseurl=${httpBaseUrl} realm=${httpBaseUrl} user="$rclone_user" pass="$rclone_pass"
          rclone rc --user "$rclone_user" --pass "$rclone_pass" --url http://localhost:${builtins.toString rcdPort}/${rcdBaseUrl} serve/start type=http fs=public: addr=:${builtins.toString httpPublicPort} baseurl=${httpPublicBaseUrl}
          envoy -c "${envoyConfig}" &
          wait -n
        '';
      };
    in
    dockerTools.buildLayeredImage {
      name = "rclone";
      tag = "latest";
      maxLayers = 10;
      contents = with pkgs.dockerTools; [
        usrBinEnv
        binSh
        caCertificates
        fakeNss

        tini

        envoy-bin

        iptables
        procps
        kmod

        coreutils
        findutils
        gnugrep
        gnused
        gawk
        bash

        socat
        rclone
        curl

        getSecret
        entrypoint
      ];

      extraCommands = ''
        mkdir -p -m 1777 ./tmp
      '';

      config = {
        ExposedPorts = {
          "${builtins.toString envoyAdminPort}/tcp" = { };
          "${builtins.toString envoyPort}/tcp" = { };
        };
        WorkingDir = "/data";
        Volumes = {
          "/data" = { };
        };
        Entrypoint = [
          "tini"
          "--"
        ];
        Cmd = [
          "/bin/${entrypointName}"
        ];
        Env = [
          # $PATH seems to be unset in fly.io
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
      };
    };

  tailscale =
    with pkgs;
    dockerTools.buildLayeredImage rec {
      name = "tailscale";
      tag = "latest";
      maxLayers = 10;
      contents = with pkgs.dockerTools; [
        usrBinEnv
        binSh
        caCertificates
        fakeNss

        iptables
        procps
        kmod

        coreutils
        findutils
        gnugrep
        gnused
        gawk
        bash

        tailscale
        headscale

        socat
        gost
        caddy
        rclone

        (writeShellApplication {
          name = "container-entrypoint";
          text = ''
            modprobe xt_mark || true

            sysctl net.ipv4.ip_forward=1 || true
            sysctl net.ipv6.conf.all.forwarding=1 || true
            if interface="$(awk '$8 == "00000000" {print}' /proc/net/route | sort --batch-size=1000 -k7 | awk '{print $1; exit}')"; then
                iptables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE || true
                ip6tables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE || true
            else
                iptables -t nat -A POSTROUTING -j MASQUERADE || true
                ip6tables -t nat -A POSTROUTING -j MASQUERADE || true
            fi

            hostname="$HOSTNAME"
            is_fly_io=
            if [[ -v FLY_REGION ]]; then
                is_fly_io=y
                hostname=fly-$FLY_REGION
            fi
            if [[ -n "$is_fly_io" ]]; then
                echo "Running on fly io."
            fi

            declare -a tailscaled_arguments=(tailscaled --verbose=1 --statedir="/data/tailscaled-$hostname")
            if [[ -v TAILSCALE_PORT ]]; then
                tailscaled_arguments+=(--port="$TAILSCALE_PORT")
            fi
            echo Running tailscale "''${tailscaled_arguments[@]}"
            "''${tailscaled_arguments[@]}" &
            sleep 5

            if ! pgrep -f -a tailscaled; then
                exit 1
            fi

            n=0
            until tailscale up --authkey="$TAILSCALE_AUTH_KEY" --hostname="$hostname" --advertise-exit-node; do
                if [[ "$n" -ge 10 ]]; then
                    echo "Failed to bring up tailscale."
                    exit 1
                fi
                n=$((n+1))
                sleep 1
            done

            echo 'Tailscale started. Lets go!'

            wait
          '';
        })
      ];

      config = {
        Volumes = {
          "/data" = { };
        };
        Entrypoint = [
          "/bin/container-entrypoint"
        ];
        Env = [
          # $PATH seems to be unset in fly.io
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
      };
    };
}
