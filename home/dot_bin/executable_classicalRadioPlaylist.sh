#!/usr/bin/env bash
set -euo pipefail

declare -a all_servers=()

dns_lookup=$(dig +short all.api.radio-browser.info)

while IFS= read -r ip; do
  reverse_dns=$(dig +short -x "$ip")
  all_servers+=("$reverse_dns")
done <<<"$dns_lookup"

download() {
  tag="$1"
  path="$2"
  format="$3"
  if [[ -d "$path" ]]; then
    path="$path/${tag// /_}.$format"
  fi
  # Try all servers until one works
  declare -a parameters=()
  parameters=("tag=$tag" "tagExact=true" "order=votes" "reverse=true" "hidebroken=true" "limit=100")
  declare -a final_parameters=()
  for parameter in "${parameters[@]}"; do
    final_parameters+=("--data-urlencode")
    final_parameters+=("$parameter")
  done
  for server in "${all_servers[@]}"; do
    # If the request is successful, break the loop
    if curl --get "${final_parameters[@]}" "https://$server/$format/stations/search" -o "$path"; then
      break
    fi
  done
}

download "classical music" ~/Sync/media/ m3u
download "classical music" ~/Sync/media/ pls
download "classical music" ~/Sync/media/ json
