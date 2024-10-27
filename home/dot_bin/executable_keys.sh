#!/usr/bin/env bash
program="$(basename "$0")"
usage() {
        cat - <<EOF
usage: $program store title [attribute value] ...
$program lookup title [attribute value] ...
$program clear title [attribute value] ...
$program search [--all] [--unlock] title [attribute value] ...
EOF
}
if [[ "$#" -eq "0" ]]; then
        usage
        exit
else
        subcommand="$1"
        shift
        name="$1"
        shift
        case "$subcommand" in
        store | set)
                secret-tool store "--label=$name" Title "$name" "$@"
                ;;
        lookup | get)
                secret-tool lookup Title "$name" "$@"
                ;;
        clear | delete)
                secret-tool clear Title "$name" "$@"
                ;;
        search)
                secret-tool search --all Title "$name" "$@"
                ;;
        *)
                usage
                ;;
        esac

fi
