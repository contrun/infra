#!/usr/bin/env -S uv run python
# /// script
# dependencies = [
#   "invoke",
# ]
# ///

import os
import shutil
import socket
import sys
from datetime import datetime, timezone
from pathlib import Path

from invoke.collection import Collection
from invoke.context import Context
from invoke.program import Program
from invoke.tasks import task

# --- Project Paths & Defaults ---
SCRIPT_DIR = Path(__file__).resolve().parent
IGNORED_DIR = SCRIPT_DIR / "ignored"
TMP_DIR = SCRIPT_DIR / "tmp"

DEFAULT_HOST = socket.gethostname()
DEFAULT_USER = os.getlogin()
DEFAULT_HOME = str(Path.home())


# --- Helper Methods ---
def get_command(c: Context, name: str, fallback_cmd: str) -> str:
    """Check if a command exists on PATH; if not, return the nix run fallback."""
    if shutil.which(name):
        return name
    return fallback_cmd


def get_nix_flags(system: str | None = None, extra_flags: str | None = None) -> str:
    flags = []
    if system:
        flags.extend(["--system", system, "--extra-extra-platforms", system])
    flags.extend(["--impure", "--show-trace", "--keep-going", "--print-build-logs"])
    if extra_flags:
        flags.append(extra_flags)
    return " ".join(flags)


# --- Git Tasks ---
@task
def pull(c: Context):
    """Pull upstream changes with rebase and autostash."""
    c.run("git pull --rebase --autostash")


@task
def push(c: Context):
    """Commit and push changes interactively."""
    c.run("git status")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    c.run(f'git commit -a -m "auto push at {now}"')
    c.run("git log HEAD^..HEAD")
    c.run("git diff HEAD^..HEAD")
    input("Press Enter to continue, or Ctrl+C to exit...")
    c.run("git push")


@task
def autopush(c: Context):
    """Auto-commit and push without prompt."""
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    c.run(f'git commit -a -m "auto push at {now}"')
    c.run("git push")


@task(pre=[pull, push])
def upload(c: Context):
    """Pull and push changes."""


@task(pre=[pull])
def update(c: Context, host=DEFAULT_HOST):
    """Pull changes and update nix flake inputs."""
    update_upstreams(c)


@task
def update_upstreams(c: Context):
    """Update Nix flake dependencies."""
    c.run("nix flake update")


# --- Utility Tasks ---
@task
def create_tmp_dirs(c: Context):
    """Ensure temporary directories exist."""
    TMP_DIR.mkdir(parents=True, exist_ok=True)


@task
def clean(c: Context):
    """Remove build artifacts and temporary files."""
    if TMP_DIR.exists():
        shutil.rmtree(TMP_DIR)

    result_link = SCRIPT_DIR / "result"
    if result_link.is_symlink() and os.readlink(result_link).startswith("/nix/store/"):
        result_link.unlink()


@task
def sops(c: Context):
    """Edit SOPS secrets."""
    c.run("sops ./nix/sops/secrets.yaml")


# --- Chezmoi Management Tasks ---
@task
def chezmoi_cmd(
    c: Context, action, dest=DEFAULT_HOME, src=str(SCRIPT_DIR), verbose=False
):
    """Run generic chezmoi command (init, update, status, apply, purge, managed)."""
    v_flag = "-v" if verbose else ""
    c.run(f'chezmoi -D "{dest}" -S "{src}" {action} {v_flag} --keep-going')


@task
def home_install(c: Context, dest=DEFAULT_HOME, verbose=False):
    """Apply chezmoi configurations for home directory."""
    v_flag = "-v" if verbose else ""
    c.run(f'chezmoi {v_flag} --keep-going -D "{dest}" -S "{SCRIPT_DIR}" apply')


@task
def home_uninstall(c: Context, dest=DEFAULT_HOME, verbose=False):
    """Purge chezmoi home configurations."""
    v_flag = "-v" if verbose else ""
    c.run(f'chezmoi {v_flag} --keep-going -D "{dest}" -S "{SCRIPT_DIR}" purge')


# --- Home Manager Tasks ---
@task
def home_manager(
    c: Context, host=DEFAULT_HOST, user=DEFAULT_USER, system=None, extra_nix_flags=""
):
    """Switch Home Manager configuration."""
    cmd = get_command(c, "home-manager", "nix run .#home-manager --")
    flags = get_nix_flags(system, extra_nix_flags)
    c.run(f'{cmd} switch --flake ".#{user}@{host}" {flags}')


@task
def home_manager_build(
    c: Context, host=DEFAULT_HOST, user=DEFAULT_USER, system=None, extra_nix_flags=""
):
    """Build Home Manager configuration."""
    cmd = get_command(c, "home-manager", "nix run .#home-manager --")
    flags = get_nix_flags(system, extra_nix_flags)
    c.run(f'{cmd} build --flake ".#{user}@{host}" {flags}')


@task
def home_manager_bootstrap(c: Context, system=None, extra_nix_flags=""):
    """Bootstrap Home Manager configuration on current system."""
    cmd = get_command(c, "home-manager", "nix run .#home-manager --")
    flags = get_nix_flags(system, extra_nix_flags)
    arch = c.run(
        "nix eval --raw --expr 'builtins.currentSystem'", hide=True
    ).stdout.strip()
    c.run(f'{cmd} switch --flake ".#cicd-{arch}" {flags}')


# --- NixOS Operations ---
@task(pre=[create_tmp_dirs])
def nixos_prefs(c: Context, host=DEFAULT_HOST):
    """Export host NixOS preferences to JSON."""
    jq = "jq" if shutil.which("jq") else "cat"
    cmd = (
        f"nix eval --impure --raw --expr "
        f'"(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.{host}.config.passthru.prefsJson"'
        f" | {jq} | tee tmp/prefs.{host}.json"
    )
    c.run(cmd)


@task
def nixos_deploy(
    c: Context,
    host=DEFAULT_HOST,
    no_rollback=False,
    no_fast_connection=False,
    extra_deploy_flags="",
    extra_nix_flags="",
):
    """Deploy NixOS configuration using deploy-rs."""
    deploy = get_command(c, "deploy", "nix run .#deploy-rs --")
    deploy_flags = ["--skip-checks", "--debug-logs"]

    if no_rollback:
        deploy_flags.extend(["--auto-rollback=false", "--magic-rollback=false"])
    if no_fast_connection:
        deploy_flags.append("--fast-connection=false")
    if extra_deploy_flags:
        deploy_flags.append(extra_deploy_flags)

    d_flags = " ".join(deploy_flags)
    n_flags = get_nix_flags(extra_flags=extra_nix_flags)

    c.run(f'{deploy} {d_flags} ".#{host}" -- {n_flags}')


@task
def nixos_build(
    c: Context, host=DEFAULT_HOST, build_type="toplevel", extra_nix_flags=""
):
    """Build NixOS configuration."""
    flags = get_nix_flags(extra_flags=extra_nix_flags)
    c.run(
        f'nix build ".#nixosConfigurations.{host}.config.system.build.{build_type}" --print-out-paths {flags}'
    )


@task
def nixos_switch(c: Context, host=DEFAULT_HOST, extra_nix_flags=""):
    """Switch to target NixOS configuration."""
    flags = get_nix_flags(extra_flags=extra_nix_flags)
    c.run(f'sudo nixos-rebuild switch --flake ".#{host}" {flags}')


@task
def nixos_bootloader(c: Context, host=DEFAULT_HOST, extra_nix_flags=""):
    """Switch NixOS system configuration and reinstall bootloader."""
    flags = get_nix_flags(extra_flags=extra_nix_flags)
    c.run(f'sudo nixos-rebuild switch --flake ".#{host}" --install-bootloader {flags}')


@task(pre=[create_tmp_dirs])
def nixos_profile_path_info(c: Context, host=DEFAULT_HOST, extra_nix_flags=""):
    """Inspect and sort Nix store output size paths."""
    flags = get_nix_flags(extra_flags=extra_nix_flags)
    out_path = c.run(
        f'nix build ".#nixosConfigurations.{host}.config.system.build.toplevel" {flags} --print-out-paths',
        hide=True,
    ).stdout.strip()
    log_file = TMP_DIR / f"nixos-profile-path-info.{host}"

    c.run(f"nix path-info -sShr '{out_path}' | tee {log_file}")
    c.run(f"sort -h -k2 < {log_file}")
    c.run(f"sort -h -k3 < {log_file}")


@task
def nixos_generate(c: Context, host=DEFAULT_HOST, format="iso"):
    """Generate NixOS images (ISO, VM, etc.) using nixos-generate."""
    gen = get_command(c, "nixos-generate", "nix run .#nixos-generate --")
    c.run(f'{gen} -f {format} --flake ".#{host}"')


@task
def nixos_vagrant_box(c: Context):
    """Generate Vagrant VirtualBox target."""
    gen = get_command(c, "nixos-generate", "nix run .#nixos-generate --")
    c.run(f'{gen} -f vagrant-virtualbox --flake ".#dbx"')


# --- Cachix Binary Cache ---
@task(pre=[create_tmp_dirs])
def cachix_push(c: Context, host=DEFAULT_HOST):
    """Push derivation dependencies to Cachix binary cache."""
    nixos_build(c, host=host)
    flags = get_nix_flags()
    paths_file = TMP_DIR / "cachix-push.paths"

    c.run(
        f'nix derivation show {flags} -r ".#nixosConfigurations.{host}.config.system.build.toplevel" '
        f"| jq -r '.[].outputs[].path' "
        f'| xargs -i sh -c \'test -f "{{}}" && echo "{{}}"\' > {paths_file}'
    )

    ignore_pattern = (
        "clion|webstorm|idea-ultimate|goland|pycharm-professional|datagrip|android-studio-dev|"
        "graalvm11-ce|lock$|-source$|ndk-bundle|vivaldi|sources-android|commandlinetools-linux"
    )

    c.run(
        f"grep -vE '{ignore_pattern}' {paths_file} | cachix push contrun -m zstd -c 16 -j 1"
    )


@task
def cachix_push_all(c: Context):
    """Push closure paths for multi-arch build environments."""
    cachix_push(c, host="cicd-x86_64-linux")
    cachix_push(c, host="cicd-aarch64-linux")


# --- Ansible Workflows ---
@task
def ansible_install_requirements(c: Context):
    """Install required Ansible collections and roles."""
    with c.cd("ansible"):
        c.run(
            "ansible-galaxy collection install -p galaxy-collections -r requirements.yml"
        )
        c.run("ansible-galaxy role install -p galaxy-roles -r requirements.yml")


@task
def ansible_diff_inventory_hosts(c: Context):
    """Diff decrypted Ansible inventory against Git HEAD."""
    with c.cd("ansible"):
        c.run(
            "diff <(git cat-file blob HEAD:ansible/inventory/hosts.yml | ansible-vault view -) <(ansible-vault view inventory/hosts.yml)"
        )


@task
def ansible_view_inventory_hosts(c: Context):
    """Decrypt and display inventory file."""
    with c.cd("ansible"):
        c.run("ansible-vault view inventory/hosts.yml")


@task
def ansible_edit_inventory_hosts(c: Context):
    """Edit encrypted inventory file."""
    with c.cd("ansible"):
        c.run("ansible-vault edit inventory/hosts.yml")


@task
def ansible_deploy_services(c: Context, services="", extra_flags=""):
    """Deploy ansible services playbook."""
    with c.cd("ansible"):
        c.run(
            f"ansible-playbook services.yml --extra-vars services={services} {extra_flags}".strip()
        )


@task
def ansible_configure_hosts(c: Context, services="", hosts="", extra_flags=""):
    """Configure target Ansible hosts."""
    with c.cd("ansible"):
        c.run(
            f"ansible-playbook hosts.yml --extra-vars services={services} --extra-vars hsts={hosts} {extra_flags}".strip()
        )


@task
def ansible_configure_ssh_ca_yubikey(
    c: Context,
    type="both",
    hosts="",
    force_sign="",
    host_key="",
    user_key="",
    extra_flags="",
):
    """Configure YubiKey SSH CA signing via Ansible."""
    service_var = (
        "ssh-host-ca"
        if type == "host"
        else ("ssh-user-ca" if type == "user" else "ssh-host-ca,ssh-user-ca")
    )

    askpass_path = (
        c.run("nix build --print-out-paths .#seahorse.out", hide=True).stdout.strip()
        + "/libexec/seahorse/ssh-askpass"
    )
    lib_path = (
        c.run(
            "nix build --print-out-paths nixpkgs#yubico-piv-tool.out", hide=True
        ).stdout.strip()
        + "/lib/libykcs11.so"
    )

    vars_cmd = [
        f"--extra-vars services={service_var}",
        f"--extra-vars hsts={hosts}",
        f'--extra-vars pkcs11_library_path="{lib_path}"',
        f"--extra-vars host_force_sign={force_sign}",
        f"--extra-vars user_force_sign={force_sign}",
    ]

    if user_key:
        vars_cmd.append(f"--extra-vars user_ssh_key_path={user_key}")
    if host_key:
        vars_cmd.append(f"--extra-vars host_ssh_key_path={host_key}")

    full_vars = " ".join(vars_cmd)

    with c.cd("ansible"):
        c.run(
            f'SSH_ASKPASS="{askpass_path}" ansible-playbook hosts.yml {full_vars} {extra_flags}'.strip()
        )


@task
def ansible_generate_lock(c: Context):
    """Generate lockfile for Ansible configs."""
    with c.cd("ansible"):
        c.run("./generate-lock.sh")


# --- Deployment Services ---
@task
def flyctl_deploy(c: Context, service):
    """Deploy target service to Fly.io."""
    c.run(f"flyctl deploy -c fly/{service}/fly.toml")


# --- CLI Entrypoint ---
# Automatically collect all tasks defined in this module
ns = Collection.from_module(sys.modules[__name__])
ns.default = "nixos_deploy"

if __name__ == "__main__":
    Program(namespace=ns, version="1.0.0").run()
