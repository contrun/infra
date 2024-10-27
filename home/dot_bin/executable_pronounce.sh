#!/usr/bin/env bash

timeout=5s

with_curl=
if command -v curl >/dev/null; then
  with_curl=y
fi
with_mplayer=
if command -v mplayer >/dev/null; then
  with_mplayer=y
fi
with_urlencode=
if command -v urlencode >/dev/null; then
  with_urlencode=y
fi
with_timeout=
if command -v timeout >/dev/null; then
  with_timeout=y
fi

lookup_file="$HOME/.local/share/lookups.csv"
mkdir -p "$(dirname "$lookup_file")"

maybe_run_with_timeout() {
  if [[ -z "$with_timeout" ]]; then
    "$@"
  else
    timeout "$timeout" "$@"
  fi
}

pronounce_word_with_provider() {
  local provider="$1"
  local word="$2"
  if [[ -n "$with_urlencode" ]]; then
    word="$(urlencode "$word")"
  fi
  local url
  case "$provider" in
  youdao)
    url="https://dict.youdao.com/dictvoice?type=2&audio=${word}"
    # url="http://127.0.0.1/test"
    ;;
  baidu)
    url="https://sensearch.baidu.com/gettts?lan=en&spd=3&source=alading&text=${word}"
    ;;
  *)
    exit 1
    ;;
  esac

  if [[ -n "$with_curl" ]] && [[ -n "$with_mplayer" ]]; then
    maybe_run_with_timeout bash -c '$@' -- curl "$url" | maybe_run_with_timeout mplayer -cache 1024 -
  else
    maybe_run_with_timeout mpv "$$url"
  fi
}

pronounce_word() {
  pronounce_word_with_provider youdao "$1"
}

lookup_word() {
  local word="$1"
  sdcv --data-dir="$HOME/Storage/dict" -n -c "$word" | less
}

go() {
  local word
  for word in "$@"; do
    # remove leading whitespace characters
    word="${word#"${word%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    word="${word%"${word##*[![:space:]]}"}"
    if [[ -z "$word" ]]; then
      continue
    fi
    # Save my look up of works to this file for later usage
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"),${word}" >>"$lookup_file"
    pronounce_word "$word"
    lookup_word "$word"
  done
}

if [[ $# -eq 0 ]]; then
  go "$(wl-paste)"
else
  go "$@"
fi
