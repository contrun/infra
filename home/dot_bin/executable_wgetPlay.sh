#!/bin/sh
export PATH=/usr/local/git/bin:/usr/local/bin:$PATH
export http_proxy='http://127.0.0.1:8118'; export https_proxy=http://127.0.0.1:8118; export ftp_proxy=http://127.0.0.1:8118; export rsync_proxy=http://127.0.0.1:8118; export all_proxy=http://127.0.0.1:8118; export HTTP_PROXY=http://127.0.0.1:8118; export HTTPS_PROXY=http://127.0.0.1:8118; export FTP_PROXY=http://127.0.0.1:8118; export RSYNC_PROXY=http://127.0.0.1:8118; export ALL_PROXY=http://127.0.0.1:8118; export no_proxy='localhost,127.0.0.1,localaddress,.localdomain.com'
export LC_ALL=en_US.utf-8
export LANG=en_US.utf-8
mkdir -p /tmp/d
cd /tmp/d
exec >> wget.log
exec 2>&1
if [[ $(uname) == 'Linux' ]]; then
	title="$(xclip -o -selection clipboard)"
elif [[ $(uname) == 'Darwin' ]]; then
	title="$(pbpaste)"
else
	exit 1
fi
# if grep ' - IMDb' <<< $title && ! grep 'input-file' <<< "$@"; then
if grep ' - IMDb' <<< $title; then
	title="$(sed -e 's/ - IMDb//' <<< "$title")"
	wget "$@" -O "${title}" &
	subtitle.sh "${title}" &
	wait
	mpv "${title}"
else
	wget "$@"
fi
exit
