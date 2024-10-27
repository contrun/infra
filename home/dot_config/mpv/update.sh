#!/usr/bin/env bash
cd "$(dirname "$(readlink -f "$0")")"
get_github_latest() {
    curl -s "https://api.github.com/repos/$1/$2/releases/latest" | grep 'browser_' | cut -d\" -f4 | grep "$3"
}
list="$(cat << EOF
https://raw.githubusercontent.com/torque/mpv-progressbar/build/progressbar.lua
scripts/progressbar.lua
https://raw.githubusercontent.com/zenyd/mpv-scripts/master/speed-transition.lua
scripts/speed-transition.lua
https://raw.githubusercontent.com/wiiaboo/mpv-scripts/master/subit.lua
scripts/subit.lua
https://raw.githubusercontent.com/kelciour/mpv-scripts/master/sub-search.lua
scripts/sub-search.lua
https://raw.githubusercontent.com/zc62/mpv-scripts/master/save-sub-delay.lua
scripts/save-sub-delay.lua
https://raw.githubusercontent.com/rumkex/osdb-mpv/master/osdb.lua
scripts/osdb.lua
https://raw.githubusercontent.com/directorscut82/find_subtitles/master/find_subtitles.lua
scripts/find_subtitles.lua
$(get_github_latest TheAMM mpv_crop_script mpv_crop_script)
scripts/mpv_crop_script.lua
$(get_github_latest TheAMM mpv_thumbnail_script mpv_thumbnail_script_server)
scripts/mpv_thumbnail_script_server.lua
$(get_github_latest TheAMM mpv_thumbnail_script mpv_thumbnail_script_client_osc)
scripts/mpv_thumbnail_script_client_osc.lua
https://raw.githubusercontent.com/Kagami/mpv_frame_info/master/frame_info.lua
scripts/frame_info.lua
https://raw.githubusercontent.com/Argon-/mpv-stats/master/stats.lua
scripts/stats.lua
https://raw.githubusercontent.com/gthreepw00d/mpv-iptv/master/iptv.lua
scripts/iptv.lua
EOF
)"
urls="$(awk 'NR % 2 != 0' <<< "$list")"
filenames="$(awk 'NR % 2 == 0' <<< "$list")"
for i in $(seq 1 $(wc <<< "$urls" | awk '{print $1}')); do
	url="$(sed -ne "${i}p" <<< "$urls")"
	filename="$(sed -ne "${i}p" <<< "$filenames")"
	wget "$url" -O "$filename"
done
