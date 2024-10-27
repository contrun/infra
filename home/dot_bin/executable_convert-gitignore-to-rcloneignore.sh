#!/usr/bin/env bash

set -euo pipefail

# Mostly copied from
# https://github.com/rclone/rclone/issues/671#issuecomment-1153700933

if ! cd "$@"; then
  >&2 echo "Folder $* not found"
  exit 1
fi

rcloneignore=.rcloneignore
tmprcloneignore=.rcloneignore.tmp

if [[ -f "$rcloneignore" ]] && [[ -z "$(find ./ -type f -name '.gitignore' -newer "$rcloneignore" -print0)" ]]; then
  >&2 echo "No newer gitignore file found, exiting"
  exit 0
fi

while IFS= read -r -d $'\0' path <&3; do
  root="$(dirname "$path")/"
  root=${root#.}

  while IFS= read -r ignore || [[ -n "$ignore" ]]; do
    # A line starting with # serves as a comment.
    [[ $ignore =~ ^# ]] && continue

    # Trim spaces using parameter expansion
    # Starting and trailling whitespace can be escaped with \, but we ignore that anyway
    ignore="${ignore##+([[:space:]])}"

    # Ignore empty lines
    [[ -z "$ignore" ]] && continue

    # An optional prefix "!" which negates the pattern.
    if [[ $ignore == !* ]]; then
      # Use parameter expansion instead of sed
      ignore="${ignore#!}"
      include=true
    else
      include=false
    fi

    pattern="$ignore"

    # A pattern with a slash in the middle or beginning means this is a absolute path,
    # while a trailing slash means this is a directory.
    if [[ "${ignore%/}" =~ / ]]; then
      pattern="${root%/}/${pattern#/}"
    else
      # Mimic relative search by making an absolute WRT to current directory,
      # preceded by a recursive glob `**`
      pattern="${root%/}/**/$pattern"
    fi

    if [[ $include = true ]]; then
      pattern="+ $pattern"
    else
      pattern="- $pattern"

    fi

    # A separator at the end only matches directories
    if [[ $ignore =~ /$ ]]; then
      # rclone only matches files, so we need to add `**` to match a directory
      echo "$pattern**"
    else
      # The pattern doesn't end with `/`, it may be a file or a directory
      # The output below is for the case this is a file
      echo "$pattern"
      # The output below is for the case this is a directory
      echo "$pattern/**"
    fi
  done <"$path"
done 3< <(find ./ -type f -name '.gitignore' -print0) | tee "$tmprcloneignore"

# If above script exited with error and we directly updated the rcloneignore
# file, then the rcloneignore will always newer than the gitignore files.
# So we need to be sure that above script finished without error first
# before we update the rcloneignore file.
mv "$tmprcloneignore" "$rcloneignore"
