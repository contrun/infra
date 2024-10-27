#!/bin/sh
if [[ "$#" -eq 4 ]]; then
    orgProtocol.py -t "$1" url "$2" title "$3" body "$4"
elif [[ "$#" -eq 3 ]]; then
    orgProtocol.py -t "$1" title "$2" body "$3" url "$2" title "$3" body "$4"
elif [[ "$#" -eq 2 ]]; then
    orgProtocol.py -t "$1" title "$2"
elif [[ "$#" -eq 1 ]]; then
    orgProtocol.py -t "$1"
else
    echo "1-4 arguments required, $# arguments given."
fi
