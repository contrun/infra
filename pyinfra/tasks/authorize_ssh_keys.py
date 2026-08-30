import ntpath
import os
import urllib.request
from pyinfra import host
from pyinfra.facts.server import User
from pyinfra.operations import files, server

# 1. Configuration
github_user = "contrun"
keys_url = f"https://github.com/{github_user}.keys"

try:
    # 2. Fetch public keys from GitHub locally on the controller machine
    # Set SSL_CERT_FILE using certifi if not present in environment (e.g., Nix / standalone Python builds)
    if "SSL_CERT_FILE" not in os.environ:
        try:
            import certifi
            os.environ["SSL_CERT_FILE"] = certifi.where()
        except ImportError:
            pass

    with urllib.request.urlopen(keys_url) as response:
        keys_content = response.read().decode("utf-8").strip()

    if not keys_content:
        raise ValueError(f"No keys found at {keys_url}")

    # Ensure key ends with a newline for clean file appending
    keys_content = keys_content + "\n"

    # 3. Define target paths and permissions
    # pyinfra dynamically resolves user paths based on the SSH target user
    user_fact = host.get_fact(User)
    user_home = user_fact.home if (user_fact and hasattr(user_fact, "home")) else "$HOME"
    
    targets = [
        {
            "path": rf"{user_home}\.ssh\authorized_keys",
            "group": None,  # Default user ownership
        },
        {
            "path": r"C:\ProgramData\ssh\administrators_authorized_keys",
            "group": "BUILTIN\\Administrators",
        },
    ]

    # 4. Deploy keys and harden permissions to each target file
    for target in targets:
        file_path = target["path"]
        dir_path = ntpath.dirname(file_path)

        # Ensure directory exists
        files.directory(
            name=f"Ensure directory exists: {dir_path}",
            path=dir_path,
        )

        # Append unique keys to the authorized_keys file
        # 'interpolate_variables=False' prevents pyinfra from misinterpreting any '%' or '$' in SSH keys
        files.line(
            name=f"Ensure GitHub keys exist in {file_path}",
            path=file_path,
            line=keys_content,
            ensure_newline=True,
            interpolate_variables=False,
        )

        # Apply strict Windows ACLs using icacls
        # Windows OpenSSH requires exact permissions or it will reject keys
        if target["group"]:
            # Admin path: Only SYSTEM and Administrators
            acl_cmd = (
                f'icacls "{file_path}" /inheritance:r '
                f'&& icacls "{file_path}" /grant:r "SYSTEM:(F)" '
                f'&& icacls "{file_path}" /grant:r "{target["group"]}:(F)"'
            )
        else:
            # User path: Only SYSTEM and Current User
            acl_cmd = (
                f'icacls "{file_path}" /inheritance:r '
                f'&& icacls "{file_path}" /grant:r "SYSTEM:(F)" '
                f'&& icacls "{file_path}" /grant:r "%USERNAME%:(F)"'
            )

        server.shell(
            name=f"Harden permissions on {file_path}",
            commands=[acl_cmd],
        )

except Exception as e:
    # Captures execution errors prior to or during pyinfra operation definitions
    print(f"[ERROR] Failed to execute deployment setup: {e}")
