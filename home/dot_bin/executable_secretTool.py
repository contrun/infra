#!/usr/bin/env python
from __future__ import print_function

import json
import re
import sys
import os
import subprocess


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def get_secrets(account):
    if "DISPLAY" not in os.environ:
        os.environ["DISPLAY"] = ":0"
    command = ["secret-tool", "search", "Title", account]
    output = subprocess.check_output(
        command, stderr=subprocess.STDOUT).decode('utf-8')
    return {k.lower(): v for k, v in re.findall('(.*?) = (.*)', output)}


def translate_attribute(attribute):
    translation = {
        "password": "secret",
        "title": "label",
    }
    translation.update({k: k for k in ["created", "modified"]})
    translation.update({k: "attribute.{}".format(k)
                        for k in ["username", "url"]})
    attribute = attribute.lower()
    return translation.get(attribute, "attribute.{}".format(attribute))


def get_attributes(account, *attributes):
    secrets = get_secrets(account)
    if attributes:
        return {a: secrets[translate_attribute(a)] for a in attributes}
    return secrets

def get_attribute(account, attribute):
    return get_attributes(account, attribute)[attribute]


def get_attribute_int(account, attribute):
    return int(get_attribute(account, attribute))


def main():
    if len(sys.argv) < 2:
        eprint("{} name (attribute ... )".format(sys.argv[0]))
        exit(1)
    elif len(sys.argv) == 2:
        result = get_attributes(sys.argv[1])
        print(json.dumps(result, indent=4, sort_keys=True))
    elif len(sys.argv) == 3:
        print(get_attribute(sys.argv[1], sys.argv[2]))
    else:
        result = get_attributes(sys.argv[1], *sys.argv[2:])
        print(json.dumps(result, indent=4, sort_keys=True))


if __name__ == "__main__":
    main()
