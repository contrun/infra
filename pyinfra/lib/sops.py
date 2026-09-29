import io
import pathlib
import subprocess

from dotenv import dotenv_values

script_path = pathlib.Path(__file__)
default_env_path = script_path.parent.parent / ".env.secret"


def load_sops_env(env_path: str = str(default_env_path)) -> dict[str, str | None]:
    """Decrypt a SOPS-encrypted dotenv file and return its values as a dictionary."""
    cmd = [
        "sops",
        "decrypt",
        "--input-type",
        "dotenv",
        "--output-type",
        "dotenv",
        env_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return dotenv_values(stream=io.StringIO(result.stdout))
