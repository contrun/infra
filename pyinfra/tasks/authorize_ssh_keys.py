from pathlib import PurePosixPath

from pyinfra import host
from pyinfra.facts.server import User, Home
from pyinfra.operations import files, server
from pyinfra.api import FactBase

import os
import base64
import urllib.request

# Set SSL_CERT_FILE using certifi if not present in environment (e.g., Nix / standalone Python builds)
if "SSL_CERT_FILE" not in os.environ:
    try:
        import certifi
        os.environ["SSL_CERT_FILE"] = certifi.where()
    except ImportError:
        pass

github_user = "contrun"
keys_url = f"https://github.com/{github_user}.keys"

with urllib.request.urlopen(keys_url) as response:
    keys_content = response.read().decode("utf-8").strip()

if not keys_content:
    raise ValueError(f"No keys found at {keys_url}")

keys = [i.strip() for i in keys_content.strip().splitlines() if i.strip()]

current_user = host.get_fact(User)
path_home = host.get_fact(Home)
dir_path = PurePosixPath(path_home) / ".ssh"
file_path = dir_path / "authorized_keys"
current_user = host.get_fact(User)

files.directory(
    name=f"Ensure SSH directory exists: {dir_path}",
    path=str(dir_path),
    mode="700",
    user=current_user,
)

for key in keys:
    files.line(
        name=f"Ensure GitHub key exists in {file_path}",
        path=str(file_path),
        line=key,
        ensure_newline=True,
        interpolate_variables=False,
    )

files.file(
    name=f"Harden permissions on {file_path}",
    path=str(file_path),
    mode="600",
    user=current_user,
)
