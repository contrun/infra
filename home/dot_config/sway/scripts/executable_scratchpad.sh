#!/bin/bash

SCREENWIDTH=1920
SCREENHEIGHT=1080

# check for number of arguments and print help
if [ $# -lt 4 ]
then
	echo "usage: $(basename $0) <class> <width> <height> <command>"
	exit
fi

# process arguments
CLASS=$1
WIDTH=$2
HEIGHT=$3
shift 3
CMD="$*"

# get end position for the window
POSX=$(( SCREENWIDTH/2 - WIDTH/2 ))
POSY=$(( SCREENHEIGHT/2 - HEIGHT/2 ))

# if there are no instances, launch one
if ! pgrep -x $CMD
then
	exec $CMD &
	# wait for the window to appear and get the ID
	WID=$(xdotool search --class --onlyvisible --sync $CLASS)
	# move to scratchpad and show it
	i3-msg "[class=(?i)$CLASS] move scratchpad"
	i3-msg "[class=(?i)$CLASS] scratchpad show"
	# resize and reposition
	xdotool windowsize $WID $WIDTH $HEIGHT windowmove $WID $POSX $POSY
else
	# show/toggle the scratchpad for this class if it's already running
	i3-msg  "[class=(?i)$CLASS] scratchpad show"
fi
