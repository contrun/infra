#!/usr/bin/env bash
set -euo pipefail
wp_base_url=
base_url=
username=
password=
hugo_dir="$PWD"
while getopts "w:u:p:b:d:" opt; do
	case $opt in
	w)
		wp_base_url="$OPTARG"
		;;
	u)
		username="$OPTARG"
		;;
	p)
		password="$OPTARG"
		;;
	b)
		base_url="$OPTARG"
		;;
	d)
		hugo_dir="$OPTARG"
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		exit
		;;
	esac
done

usage() {
	echo "$0 -w wordpress_url -u wordpress_username -p wordpress_password -b base_url -d directory_to_save_to"
}

if ! [[ -d "$hugo_dir" ]] || [[ -z "$wp_base_url" ]] || [[ -z "$username" ]] || [[ -z "$password" ]] || [[ -z "$base_url" ]]; then
	usage
	exit 1
fi

if curl -s "${wp_base_url}/wp-login.php" --data "log=${username}&pwd=${password}&wp-submit=Log+In&testcookie=1" -c cookiejar >/dev/null; then
	echo "login failed"
	exit 1
fi

cd "$(mktemp -d)"
if ! curl -s "${wp_base_url}/wp-admin/export.php?type=jekyll" -b cookiejar -o jekyll-export.zip; then
	echo "download jekyll export failed"
	exit 2
fi
directory="$PWD"
cd "$(mktemp -d)"
unzip "$directory/jekyll-export.zip"
rm -rf "$directory/"*
hugo import jekyll . "$directory"
cd "$directory"
find content -type f -print0 | xargs -0 sed -i "s|$wp_base_url/wp-content|$base_url|g"
find content -type f -print0 | xargs -0 sed -i "s|/wp-content/|/|g"
find content -type f -print0 | xargs -0 sed -i "s|$wp_base_url|$base_url|g"
rm -rf static/wp-content/uploads/backwpup-*
dir_to_copy=(content)
for folder in "${dir_to_copy[@]}"; do
	cp -a "$folder" "$hugo_dir"
done
cp -a static/wp-content/uploads "$hugo_dir"/static
