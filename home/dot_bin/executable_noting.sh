#!/usr/bin/env bash
if [[ $(uname) == 'Linux' ]]; then
    OPEN=emacsclientmod
    FOLDER=~/Sync/docs/tex
elif [[ $(uname) == 'Darwin' ]]; then
    OPEN="emacs"
    FOLDER=~/Onedrive/Sync/docs/tex
else
    exit
fi

echo "working directory: $FOLDER"
cd "$FOLDER" || exit

searchFile() {
    IFS=$'\n' out=$(find . -maxdepth 1 -type d | cut -c 3- | grep -v -E '^\.(.*)|^$|templates' | fzf-tmux --select-1 --exit-0 --expect=ctrl-o,ctrl-n)
    key=$(head -1 <<< "$out")
    directory=$(head -2 <<< "$out" | tail -1)
}

preOpenFile() {
	if [ ! -f "$mainFile" ]; then
		cat >"$mainFile" << EOF
\documentclass[12pt]{article}
\usepackage{../templates/notesfather}
\title{$(basename "$directory")}
\author{YI}
\date{$(date -R)}

\begin{document}
\maketitle
\newpage
\tableofcontents
\newpage

\end{document}
EOF
    fi

	if [ ! -f "$currentFile" ]; then
		cat >"$currentFile" << EOF
%%% Local Variables:
%%% mode: latex
%%% TeX-master: "$directory"
%%% End:
EOF
		sed -i -e "/\\\end{document}/{i\\\\\input{$(date +%F).tex}" -e ':a;n;ba}' "$directory/$directory.tex"
	fi
}

openFile() {
	(i3-msg workspace 0:noting && i3-msg append_layout ~/.config/i3/workspace-noting.json &) &>/dev/null
    (nohup ${OPEN} "$currentFile" &>/dev/null &)
}

monitorChanges() {
    title="$(basename "$directory")"
    export title="$title"
    export -f bindKeys
    export -f gitPush
    # for some unfathomable reason, you can not use <().
    (cat <<EOF
"gitPush '$title'"
  control+Mod4+t
EOF
) > /tmp/xbindkeysrc
    xbindkeys -f /tmp/xbindkeysrc
    echo "# $!" >> /tmp/xbindkeysrc
    sleep 10
}

bindKeys() {
    zenity --question --title "git push $pid" --text "push $title to remote git repo?"
    xbindkeys -f <(cat <<EOF
"bash -c 'gitPush \'$title\''"
  control+Mod4+p
EOF)
}

gitPush() {
    title="$1"
    if zenity --question --title "git push $pid" --text "push $title to remote git repo?"; then
        error="$(echo 'git add . && git commit -m "auto push: notes of $title on $(date +%F)" && git push' | bash 2>&1 > /dev/null)"
        if [[ $? -ne 0 ]]; then
            zenity --error --text="$error" --title="pushing $title error"
        else
            notify-send -t 3000 "pushing $title to remote finished without error"
            pkill "xbindkeys -f /tmp/xbindkeysr"
        fi
    fi
}

searchFile
if [ -n "$out" ]; then
	if [ 'ctrl-n' = "$key" ]; then
		directory="$(zenity  --title 'Create a new folder' --entry --text 'Please type in the name of the folder')"
		mkdir -p "$directory"
	fi
    mainFile="$directory/$directory.tex"
	currentFile="$directory/$(date +%F).tex"
    echo "directory: $directory"
    echo "currentFile: $currentFile"
	preOpenFile
	openFile
    monitorChanges
else
	exit
fi
