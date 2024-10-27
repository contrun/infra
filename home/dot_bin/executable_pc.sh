#!/usr/bin/env bash
pc=proxychains4
which proxychains >/dev/null 2>&1 && pc=proxychains
"$pc" "$@"
