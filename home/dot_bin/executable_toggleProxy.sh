#!/usr/bin/env bash
if [[ $(uname) == 'Linux' ]]; then
    :
elif [[ $(uname) == 'Darwin' ]]; then
    if parallel --will-cite networksetup -getwebproxy {} ::: Wi-Fi Ethernet | grep -q 'Enabled: Yes'; then
        parallel --will-cite networksetup {} off ::: -setsocksfirewallproxystate -setsecurewebproxystate -setwebproxystate ::: Wi-Fi Ethernet
    else
        parallel --will-cite networksetup {} on ::: -setsocksfirewallproxystate -setsecurewebproxystate -setwebproxystate ::: Wi-Fi Ethernet
    fi
else
    :
fi
