#!/usr/bin/env bash

set -euo nounset

export SHELL=$(type -p bash)

clean_artifacts_in_directory() {
  cd "$1" || return
  for build_tool in make cargo cabal stack sbt mvn gradle cmake go; do
    echo "Trying to clean up $PWD with $build_tool"
    "$build_tool" clean >&/dev/null &
  done
  wait
}

export -f clean_artifacts_in_directory

clean_up_directory() {
  find "$1" -type d -a -name .git -printf "%h\0" | xargs --verbose -P10 -0 -I {} "$SHELL" -c "clean_artifacts_in_directory {}"
}

if [[ $# -eq 0 ]]; then
  clean_up_directory "$PWD"
fi

for d in "$@"; do
  clean_up_directory "$d"
done
