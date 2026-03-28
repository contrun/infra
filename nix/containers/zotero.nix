{
  pkgs,
  lib,
  packages,
  zotero-plugins,
  ...
}:

with pkgs;
let
  zotero = packages.zotero;
  zoteroHome = "/home/e";
  htpasswdPath = "/tmp/.htpasswd";
  zoteroVersion = with builtins; elemAt (splitVersion zotero.version) 0;
  enabledPlugins = [
    "debug-bridge@iris-advies.com"
    "zoplicate@chenglongma.com"
  ];
  pluginPaths =
    with builtins;
    let
      zoteroPlugins = fromJSON (readFile "${zotero-plugins}/dist/plugins.json");
      releases = lib.flatten (map (x: x.releases) zoteroPlugins);
      goodReleases = filter (
        x:
        (x.targetZoteroVersion == zoteroVersion || x.id == "debug-bridge@iris-advies.com")
        && (builtins.elem x.id enabledPlugins)
      ) releases;
    in
    listToAttrs (
      builtins.map (
        x:
        let
          paths = split "gh-pages" x.xpiDownloadUrl.gitee;
          path = elemAt paths ((length paths) - 1);
        in
        {
          name = x.id;
          value = "${zotero-plugins}${path}";
        }
      ) goodReleases
    );
  plugins = pkgs.runCommand "zotero-plugins" { } ''
    mkdir -p $out/lib/distribution/
    cd $out/lib/distribution/
    ${lib.strings.concatMapAttrsStringSep "\n" (plugin: path: ''
      cp ${path} "${plugin}.xpi"
    '') pluginPaths}
  '';
  nginxConfig =
    let
      config = ''
        daemon off;
        user nobody nobody;
        error_log stderr info;
        pid /dev/null;

        events {}

        http {
            sendfile on;
            client_max_body_size 0;
            tcp_nopush on;
            tcp_nodelay on;
            keepalive_timeout 65;
            access_log /dev/stdout;

            server {
                listen *:24119;
                server_name _;
                location / {
                    proxy_pass http://127.0.0.1:23119;
                    auth_basic "Administrator’s Area";
                    auth_basic_user_file ${htpasswdPath};
                }
            }
        }
      '';
    in
    writers.writeNginxConfig "nginx.conf" config;
  userjs = ''
    user_pref("app.update.auto", false);
    user_pref("app.update.enabled", false);
    user_pref("browser.displayedE10SNotice", 4);
    user_pref("browser.dom.window.dump.enabled", true);
    user_pref("browser.download.manager.showWhenStarting", false);
    user_pref("browser.EULA.3.accepted", true);
    user_pref("browser.EULA.override", true);
    user_pref("browser.laterrun.enabled", false);
    user_pref("browser.link.open_external", 2);
    user_pref("browser.link.open_newwindow", 2);
    user_pref("browser.newtabpage.enabled", false);
    user_pref("browser.newtab.url", "about:blank");
    user_pref("browser.offline", false);
    user_pref("browser.reader.detectedFirstArticle", true);
    user_pref("browser.safebrowsing.enabled", false);
    user_pref("browser.safebrowsing.malware.enabled", false);
    user_pref("browser.search.update", false);
    user_pref("browser.selfsupport.url", "");
    user_pref("browser.sessionstore.resume_from_crash", false);
    user_pref("browser.shell.checkDefaultBrowser", false);
    user_pref("browser.startup.homepage", "about:blank");
    user_pref("browser.startup.homepage_override.mstone", "ignore");
    user_pref("browser.startup.page", 0);
    user_pref("browser.tabs.warnOnClose", false);
    user_pref("browser.tabs.warnOnOpen", false);
    user_pref("browser.usedOnWindows10.introURL", "about:blank");
    user_pref("datareporting.healthreport.logging.consoleEnabled", false);
    user_pref("datareporting.healthreport.service.enabled", false);
    user_pref("datareporting.healthreport.service.firstRun", false);
    user_pref("datareporting.healthreport.uploadEnabled", false);
    user_pref("datareporting.policy.dataSubmissionEnabled", false);
    user_pref("datareporting.policy.dataSubmissionPolicyAccepted", false);
    user_pref("datareporting.policy.firstRunURL", "");
    user_pref("devtools.browserconsole.contentMessages", true);
    user_pref("devtools.chrome.enabled", true);
    user_pref("devtools.debugger.prompt-connection", false);
    user_pref("devtools.debugger.remote-enabled", true);
    user_pref("devtools.errorconsole.enabled", true);
    user_pref("devtools.source-map.locations.enabled", true);
    user_pref("dom.disable_open_during_load", false);
    user_pref("dom.max_chrome_script_run_time", 0);
    user_pref("dom.max_script_run_time", 0);
    user_pref("dom.report_all_js_exceptions", true);
    user_pref("extensions.blocklist.enabled", false);
    user_pref("extensions.blocklist.pingCountVersion", -1);
    user_pref("extensions.checkCompatibility.nightly", false);
    user_pref("extensions.enabledScopes", 15);
    user_pref("extensions.getAddons.cache.enabled", false);
    user_pref("extensions.logging.enabled", true);
    user_pref("extensions.update.enabled", false);
    user_pref("extensions.update.notifyUser", false);
    user_pref("extensions.zotero.automaticScraperUpdates", true);
    user_pref("extensions.zotero.debug-bridge.token", "def");
    user_pref("extensions.zotero.debug.log", true);
    user_pref("extensions.zotero.debug.store", true);
    user_pref("extensions.zotero.debug.time", true);
    user_pref("extensions.zotero.firstRun2", false);
    user_pref("extensions.zotero.firstRunGuidance", false);
    user_pref("extensions.zotero.firstRunGuidanceShown.z7Banner", false);
    user_pref("extensions.zotero.httpServer.localAPI.enabled", true);
    user_pref("extensions.zoteroMacWordIntegration.installed", true);
    user_pref("extensions.zotero.reportTranslationFailure", false);
    user_pref("javascript.enabled", true);
    user_pref("javascript.options.showInConsole", true);
    user_pref("network.captive-portal-service.enabled", false);
    user_pref("network.http.phishy-userpass-length", 255);
    user_pref("network.manage-offline-status", false);
    user_pref("offline-apps.allow_by_default", true);
    user_pref("prompts.tab_modal.enabled", false);
    user_pref("security.csp.enable", false);
    user_pref("security.fileuri.origin_policy", 3);
    user_pref("security.fileuri.strict_origin_policy", false);
    user_pref("signon.rememberSignons", false);
    user_pref("startup.homepage_welcome_url", "about:blank");
    user_pref("startup.homepage_welcome_url.additional", "about:blank");
    user_pref("toolkit.networkmanager.disable", true);
    user_pref("toolkit.telemetry.enabled", false);
    user_pref("toolkit.telemetry.prompted", 2);
    user_pref("toolkit.telemetry.rejected", true);
    user_pref("urlclassifier.updateinterval", 172800);
    user_pref("webdriver_accept_untrusted_certs", true);
    user_pref("webdriver_assume_untrusted_issuer", true);
    user_pref("webdriver_enable_native_events", true);
    user_pref("xpinstall.enabled", true);
    user_pref("xpinstall.signatures.required", false);
    user_pref("xpinstall.whitelist.required", false);
  '';
  # Username: user, password: xC7hWHAkh7dcQeK94Zq7WjgY
  htpasswd = ''
    user:$apr1$9YuHKers$6vgXSay0To.p4f1CuOB9//
  '';
  entrypoint = writeShellScriptBin "container-entrypoint" ''
    #!/bin/sh
    set -eu
    if ! [ -d .zotero ]; then
      zotero --headless --createprofile managed
      cd .zotero/zotero/*.managed
      if ! [ -d extensions ]; then
        mkdir -p extensions
        cp /lib/distribution/*.xpi extensions
      fi
      [ -f user.js ] || cat > user.js <<EOF
      ${userjs}
    EOF
    fi
    if [ -n "''${HTPASSWD:-}" ]; then
      echo "''${HTPASSWD:-}" > ${htpasswdPath}
    else
      cat > ${htpasswdPath} <<-"EOF"
    ${htpasswd}
    EOF
    fi
    zotero --headless &
    curl --retry 300 --retry-delay 0.1 --retry-connrefused http://127.0.0.1:23119
    nginx -c "${nginxConfig}" &
    wait -n
  '';
in
dockerTools.buildLayeredImage {
  name = "zotero";
  tag = "latest";
  contents = with pkgs.dockerTools; [
    usrBinEnv
    binSh
    caCertificates

    tini
    coreutils
    curl
    rsync
    nginx
    zotero
    plugins

    entrypoint
  ];

  extraCommands = ''
    mkdir -p -m 1777 ./tmp
  '';

  enableFakechroot = true;
  # We simulate the host paths and host environment so that we can copy existing zotero files and
  # run the container directly. This is required because certain things are hard coded with home directory path.
  # E.g. the path of Zotero folder is written to prefs.js as $HOME/Zotero.
  # With the container image below. I can just copy the files with
  # rsync -avz --progress -h --recursive --exclude='*.bak' --include='Zotero' --exclude=Zotero/storage --include='Zotero/**' --include='.zotero' --include='.zotero/**' --exclude='**' ~/ ~/.local/cache/podman-zotero-volume/
  # The run the container with
  # podman run -it --userns=keep-id --rm --name zotero -v ~/.local/cache/podman-zotero-volume:/home/e -p 24119:24119 localhost/zotero
  # We can also use rsync to sync local zotero files to a fly machine.
  # 1. Issue a ssh certificate to log into fly machine, we can save it to id_fly.io
  # flyctl ssh issue
  # 2. Forward local traffic to remote machine
  # flyctl proxy 10022:22
  # Use rsync to sync local files to remote
  # 3. rsync -e "ssh -p 10022 -i $HOME/.ssh/id_fly.io" --chown 1000:100 -avz --progress -h --recursive --exclude='*.bak' --include='Zotero' --exclude=Zotero/storage --include='Zotero/**' --include='.zotero' --include='.zotero/**' --exclude='**' ~/ root@127.0.0.1:/home/e/
  # We can also restore the zotero files with
  # rsync -e "ssh -p 10022 -i $HOME/.ssh/id_fly.io" -avz --progress -h --recursive root@127.0.0.1:/home/e/ ~/.local/cache/zotero/
  # We may need to update the zotero preferences after a while because we change the preferences locally.
  # rsync -e "ssh -p 10022 -i $HOME/.ssh/id_fly.io" --chown 1000:100 -avz --progress -h ~/.zotero/ root@127.0.0.1:/home/e/.zotero/
  fakeRootCommands = ''
    ${dockerTools.shadowSetup}
    groupadd -r -g 100 users
    useradd -r -g 100 -u 1000 --home-dir ${zoteroHome} --create-home e
  '';

  config = {
    User = "1000:100";
    Volumes = {
      "${zoteroHome}" = { };
    };
    ExposedPorts = {
      "24119/tcp" = { };
    };
    WorkingDir = "${zoteroHome}";
    Entrypoint = [
      "tini"
      "--"
    ];
    Cmd = [
      "${lib.getExe entrypoint}"
    ];
    Env = [
      # $PATH seems to be unset in fly.io
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    ];
  };
}
