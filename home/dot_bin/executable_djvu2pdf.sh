#!/usr/bin/env bash
dir="${1:-/var/www/files}"
cd "$dir"
which perl-rename >/dev/null 2>&1 && ren=perl-rename || ren=rename
$ren 's|\(auth\.\)||g; s|^\(.*?\)\s*||g' *
mkdir -p djvus
ls *.djvu >/dev/null 2>&1 && for file in *.djvu; do
    if [[ -f "${file}.aria2" ]]; then
        exit
    elif [[ ! -f "${file%.djvu}.pdf" ]]; then
        djvu2pdf "$file"
        if [[ $? -eq 0 ]]; then
            mv "$file" djvus
        fi
    else
        mv "$file" djvus
    fi
done
