#!/bin/zsh
folder='.'
if [[ `uname` == 'Linux' ]]; then
    OPEN="xdg-open"
elif [[ `uname` == 'Darwin' ]]; then
    OPEN="open"
else
    :
fi

if [[ $# -eq 0 ]] ; then
    echo '0 argument given, exiting'
    exit 0
fi

[[ -z $2 ]] || keyword='*'$1'*.'$2 && keyword='*'$1'*'
echo "searching for $keyword \n"

fileList=`find $folder -type f -iname $keyword`
if [[ -z $fileList ]]; then
    echo '0 file found, try another keyword'
else
    numResults=`echo $fileList | wc -l`
    echo "$numResults results found\n"
    echo $fileList | nl
    if [[ $numResults == 1 ]]; then
        $OPEN "$fileList"  >/dev/null 2>&1 &
    else
        echo "\nType the file you want to open, followed by [ENTER]: "
        read fileNumber
        $OPEN "$(echo $fileList | awk "NR == $fileNumber" | xargs)" >/dev/null 2>&1 &
    fi
fi
