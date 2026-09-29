import io
import pathlib
import subprocess
from json import load

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


def load_sops_json(json_path: str):
    """Decrypt a SOPS-encrypted json file and return its values."""
    cmd = [
        "sops",
        "decrypt",
        "--input-type",
        "json",
        "--output-type",
        "json",
        json_path,
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return load(io.StringIO(result.stdout))
