import io
import json
import urllib.request

from lib.keepass import must_get_keepass_entry
from lib.ssl import setup_ssl_cert
from pyinfra.context import host
from pyinfra.facts.server import Command
from pyinfra.operations import files, server, systemd

setup_ssl_cert()

entry = must_get_keepass_entry(
    group_name="network",
    entry_title="sing-box",
)

req = urllib.request.Request(
    "https://api.github.com/repos/SagerNet/sing-box/releases/latest",
)
with urllib.request.urlopen(req) as resp:
    data = json.loads(resp.read().decode())
    latest_version = data["tag_name"].lstrip("v")

if not latest_version:
    raise RuntimeError("Failed to fetch latest sing-box version from GitHub API")

installed_version = (
    host.get_fact(
        Command,
        "if [ -x /usr/local/bin/sing-box ]; then /usr/local/bin/sing-box version; fi",
    )
    or ""
)

installation_required = latest_version not in installed_version

if installation_required:
    tar_url = f"https://github.com/SagerNet/sing-box/releases/download/v{latest_version}/sing-box-{latest_version}-linux-amd64.tar.gz"

    server.shell(
        name=f"Download and update sing-box to v{latest_version}",
        commands=[
            f"curl -sSL -o /tmp/sing-box.tar.gz '{tar_url}'",
            "tar -xzf /tmp/sing-box.tar.gz -C /tmp --strip-components=1 --wildcards '*/sing-box'",
            "chmod +x /tmp/sing-box",
            "mv /tmp/sing-box /usr/local/bin/sing-box",
            "rm -f /tmp/sing-box.tar.gz",
        ],
    )

files.directory(
    name="Create /etc/sing-box directory",
    path="/etc/sing-box",
    present=True,
    mode="755",
)

CONFIG_JSON = json.dumps(
    {
        "log": {"level": "info", "timestamp": True},
        "inbounds": [
            {
                "type": "http",
                "tag": "http-in",
                "listen": "::",
                "listen_port": 3330,
                "users": [{"username": entry.username, "password": entry.password}],
            },
            {
                "type": "socks",
                "tag": "socks-in",
                "listen": "::",
                "listen_port": 3331,
                "users": [{"username": entry.username, "password": entry.password}],
            },
            {
                "type": "shadowsocks",
                "tag": "ss-in",
                "listen": "::",
                "listen_port": 3333,
                "method": "chacha20-ietf-poly1305",
                "password": entry.password,
            },
        ],
        "outbounds": [{"type": "direct", "tag": "direct"}],
    },
    indent=2,
)

config_file = files.put(
    name="Deploy sing-box configuration file",
    src=io.StringIO(CONFIG_JSON),
    dest="/etc/sing-box/config.json",
    mode="600",
)

SYSTEMD_SERVICE = """[Unit]
Description=sing-box service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=3s
LimitNOFILE=8388608

[Install]
WantedBy=multi-user.target
"""

service_file = files.put(
    name="Deploy systemd service unit",
    src=io.StringIO(SYSTEMD_SERVICE),
    dest="/etc/systemd/system/sing-box.service",
    mode="644",
)

# Reload daemon if the service unit changed
if service_file.changed:
    server.shell(
        name="Reload systemd daemon",
        commands=["systemctl daemon-reload"],
    )

systemd.service(
    name="Ensure sing-box service is running and enabled",
    service="sing-box",
    running=True,
    enabled=True,
    restarted=installation_required or config_file.changed or service_file.changed,
)
