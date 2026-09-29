from pykeepass import Entry, PyKeePass

from .sops import load_sops_env


def get_keepass_entry(
    group_name: str,
    entry_title: str,
    kp_path: str | None = None,
    kp_password: str | None = None,
) -> Entry | None:
    """Load KeePass database credentials using SOPS and return a specific KeePass entry.

    Raises:
        RuntimeError: If credentials or entry details are missing or incomplete.
    """
    if kp_path and not kp_password or kp_password and not kp_path:
        raise RuntimeError(
            "Must pass all of kp_path and kp_password or pass none of them"
        )

    if not kp_path:
        config = load_sops_env()
        kp_path = kp_path or config.get("KEEPASS_FILE_PATH")
        kp_password = kp_password or config.get("KEEPASS_FILE_PASSWORD")
        if not kp_path or not kp_password:
            raise RuntimeError(
                "Missing KEEPASS_FILE_PATH or KEEPASS_FILE_PASSWORD in environment config."
            )

    kp = PyKeePass(kp_path, password=kp_password)

    group = kp.find_groups(name=group_name, first=True)
    if not group:
        return None

    entry: Entry | None = kp.find_entries(title=entry_title, group=group, first=True)  # pyright: ignore[reportAssignmentType]

    return entry


def must_get_keepass_entry(*args, **kwargs) -> Entry:
    entry = get_keepass_entry(*args, **kwargs)
    if not entry:
        raise RuntimeError("Requested KeePass entry was not found.")
    return entry
