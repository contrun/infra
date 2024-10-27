#!/usr/bin/env bash
if [[ $(uname) == 'Linux' ]]; then
    OPEN=xdg-open
    EMACS=emacsclientmod
    FOLDER=/run/media/e/mdt/zotero/storage
    LOGDIR="$HOME/Sync/docs/tex/logbook/"
    logbookFile="$LOGDIR/logbook.tex"
elif [[ $(uname) == 'Darwin' ]]; then
    OPEN=open
    EMACS=emacsclient
    FOLDER=~/Onedrive/Sync/docs/tex
    LOGDIR=~/Sync/docs/tex/logbook
    logbookFile="$LOGDIR/logbook.tex"
else
    exit
fi

echo "working directory: $FOLDER"
cd "$FOLDER" || exit

searchFile() {
    IFS=$'\n' out=$(fzf-tmux --select-1 --exit-0 --expect=ctrl-o,ctrl-n)
    key=$(head -1 <<< "$out")
    fileName=$(head -2 <<< "$out" | tail -1)
}

preOpenFile() {
	if [ ! -f "$logFile" ]; then
		cat >"$logFile" << EOF
%%% Local Variables:
%%% mode: latex
%%% TeX-master: "logbook"
%%% End:
EOF
		sed -i -e "/\\\end{document}/{i\\\\\input{\"${file%%.*}\"}" -e ':a;n;ba}' "$logbookFile"
	fi
}

searchFile
if [ -n "$out" ]; then
	if [ 'ctrl-n' = "$key" ]; then
        (nohup zotero &)
        exit
	fi
    file="$(basename "$fileName")"
    logFile="$LOGDIR/${file%%.*}.tex"
    echo "file: $file"
    echo "logFile: $logFile"
	preOpenFile
	if [ 'ctrl-o' = "$key" ]; then
        # (i3-msg "workspace 0:reading; append_layout ~/.config/i3/workspace-reading.json" &)
        (i3-msg "workspace 0:reading" &)
        (nohup ${OPEN} "$fileName" >~/nohup.out 2>&1 &)
        # ($EMACS ~/Onedrive/docs/org-mode/gtd/superset.org &)
    else
        (nohup ${OPEN} "$fileName" >~/nohup.out 2>&1 &)
    fi
    sleep 10
else
	exit
fi
