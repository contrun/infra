import pathlib
from typing import Any

from lib.sops import load_sops_json


def normalize_host(item: Any):
    """
    Converts JSON host items (lists or dicts) to host strings or (hostname, data) tuples.
    """
    # Case 1: [hostname, {data_dict}] -> (hostname, data_dict)
    if (
        isinstance(item, list)
        and len(item) == 2
        and isinstance(item[0], str)
        and isinstance(item[1], dict)
    ):
        return (item[0], item[1])

    # Case 2: Standard string host (e.g., "adk")
    if isinstance(item, str):
        return item

    # Case 3: Tuple already (for safety)
    if (
        isinstance(item, tuple)
        and len(item) == 2
        and isinstance(item[0], str)
        and isinstance(item[1], dict)
    ):
        return item

    raise TypeError(f"Cannot convert item to valid host type: {item}")


def convert_json_inventory(json_data: Any):
    """
    Normalizes arbitrary JSON inventory data into pyinfra host types.
    """
    # If the JSON top-level is a list of hosts
    if isinstance(json_data, list):
        return [normalize_host(h) for h in json_data]

    # If the JSON top-level is a dict of groups: {"group_name": [hosts...]}
    if isinstance(json_data, dict):
        return {
            group: [normalize_host(h) for h in hosts]
            for group, hosts in json_data.items()
        }

    return normalize_host(json_data)


def make_prod():
    script_path = pathlib.Path(__file__)
    json_path = script_path.parent / "inventory.secret.json"
    json_data = load_sops_json(str(json_path))
    return convert_json_inventory(json_data)
