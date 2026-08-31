from pathlib import PurePosixPath

from pyinfra import host
from pyinfra.facts.server import User, Home
from pyinfra.operations import files, server
from pyinfra.api import FactBase

import os
import base64
import urllib.request

# Platform independent way to the the platform system name.
class PlatformSystem(FactBase):
    def command(self) -> str:
        # Note that we need to use this command almost verbatimly. Because
        # 1. there are some quirks in running script with different quote styles in powershell.
        # 2. Python outputs \r\n to the end with print expression, which is not correctly processed by pyinfra.
        return "python -c 'import platform, sys; sys.stdout.write(platform.system())'"

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

platform_system = host.get_fact(PlatformSystem)

if platform_system == "Windows":
    keys_block="\n".join(keys)

    # Single-line PowerShell script to ensure directories, append keys idempotently, and harden ACL permissions
    ps_script = fr"""
    $keys = "{keys_block}"` -split "`n" | ForEach-Object {{ $_.Trim() }} | Where-Object {{ $_ -ne "" }}
    $user_ssh = "$env:USERPROFILE\.ssh\authorized_keys"
    $admin_ssh = "$env:ProgramData\ssh\administrators_authorized_keys"
    $targets = @(
        @{{ Path = $user_ssh; Group = "$env:USERNAME" }},
        @{{ Path = $admin_ssh; Group = "BUILTIN\Administrators" }}
    )
    foreach ($target in $targets) {{
        $filePath = $target.Path
        $dirPath = Split-Path -Path $filePath -Parent
        if (-not (Test-Path -Path $dirPath)) {{
            New-Item -Path $dirPath -ItemType Directory -Force | Out-Null
        }}
        if (-not (Test-Path -Path $filePath)) {{
            New-Item -Path $filePath -ItemType File -Force | Out-Null
        }}
        $existing = Get-Content -Path $filePath -ErrorAction SilentlyContinue
        foreach ($key in $keys) {{
            if ($existing -notcontains $key) {{
                Add-Content -Path $filePath -Value $key -Encoding utf8
            }}
        }}
        $acl = Get-Acl -Path $filePath
        $acl.SetAccessRuleProtection($true, $false)
        $acl.Access | ForEach-Object {{ $acl.RemoveAccessRule($_) }} | Out-Null
        $sysRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            "NT AUTHORITY\\SYSTEM", "FullControl", "Allow"
        )
        $groupRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $target.Group, "FullControl", "Allow"
        )
        $acl.AddAccessRule($sysRule)
        $acl.AddAccessRule($groupRule)
        Set-Acl -Path $filePath -AclObject $acl
    }}
    """
    encoded_script = base64.b64encode(ps_script.strip().encode('utf-16le')).decode('utf-8')
    
    server.shell(
        name="Configure SSH keys and harden ACL permissions via PowerShell",
        commands=[f"powershell.exe -NoProfile -NonInteractive -EncodedCommand {encoded_script}"],
    )
else:
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
