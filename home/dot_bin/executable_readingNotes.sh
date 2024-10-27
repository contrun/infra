#!/usr/bin/env bash
# Use org-protocol to add new idea entry
# params: title source description

# [[ -z $1 ]] && title="$(date -R)"
window_name="$(xdotool getwindowfocus getwindowname)"
page="$(perl -ne 'print $1 if m|\[([0-9]{1,})/[0-9]{1,}\]$|' <<<"$window_name")"
path="$1"
title="$(basename "$path")"
title="${title%.*}"
path="file:$path"
# emacsclientmod "org-protocol://capture://i/$title/$2/$3"
# emacsclientmod "org-protocol://capture://c/Zen and the Art of Motorcycle Maintainence/$(xclip -out)/$1"
orgProtocol.py -t r "url" "$path" "title" "$title" "body" "$page"
# emacsclientmod "org-protocol://capture?template=r&url=$path&title=$title&body=$page"
# emacsclientmod "org-protocol://capture://z/$path/$title/$page"

# if [ "$#" -eq 3 ]; then
#   emacsclientmod "org-protocol://capture://i/$title/literature $2/$3"
# fi
