#!/usr/bin/env bash
if [[ `uname` == 'Linux' ]]; then
    OPEN="xdg-open"
    if (ls ~/.zotero/zotero/*.default/zotero/storage 1>/dev/null 2>&1); then
        folder="$(dirname ~/.zotero/zotero/*.default/zotero/storage)/storage"
    elif [[ -d ~/Zotero/storage ]]; then
	folder="$HOME/Zotero/storage"
    else
        folder="/run/media/$(id -un)/mdt/zotero/storage"
    fi
elif [[ `uname` == 'Darwin' ]]; then
    OPEN="open"
    folder="$(dirname ~/.zotero/zotero/*.default/zotero/storage)/storage"
else
    :
fi

if [[ ! -d $folder ]]; then
    echo "zotero folder $folder error"
    exit 1
fi

fo.sh "$folder"

# if [[ $# -eq 0 ]] ; then
#     echo '0 argument given, exiting'
#     exit 0
# fi
# 
# echo $@ $#
# [ -z $2 ] && keyword='*'$1'*' || keyword="*${1}*.${2}"
# echo "searching for $keyword \n"
# 
# fileList=`find $folder -type f -iname $keyword`
# if [[ -z $fileList ]]; then
#     echo '0 file found, try another keyword'
# else
#     numResults=`echo $fileList | wc -l`
#     echo "$numResults results found\n"
#     echo $fileList | awk '{print NR, "\t", $0}'
#     if [[ $numResults == 1 ]]; then
#         $OPEN "$fileList"  >/dev/null 2>&1 &
#     else
#         echo "\nType the file you want to open, followed by [ENTER]: "
#         read fileNumber
#         $OPEN "$(echo $fileList | awk "NR == $fileNumber" | xargs)" >/dev/null 2>&1 &
#     fi
# fi
