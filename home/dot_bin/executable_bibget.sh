#!/usr/bin/env bash
version=1.8
# Thanks to Jakob Kellner for warning us about MathSciNet including &???; into the TeX code:
# TITLE = {Two cardinal invariants of the continuum {$(\germ d&lt;\germ a)$} ....
# We will try to strip some of these off...

# Set debug to 1 or greater to see the debugging output
# Alternatively, add the option '--debug'
debug=0

# Below is an example of how you should NOT write scripts.

# Will use either wget or lynx or curl (in this order), whatever is available.
WGET="$(which wget)"
if [ "$WGET" != "" ]; then
	WGETOPTS="-q -nv -O -"
else
	WGET="$(which lynx)"
	if [ "$WGET" != "" ]; then
		WGETOPTS="-source"
	else
		WGET="$(which curl)"
		if [ "$WGET" != "" ]; then
			WGETOPTS="-s -o -"
		else
			echo "
bibget may use either $(wget' or `lynx' or)curl' as its back-end, but neither seems unavailable.
Please make sure either $(wget' or `lynx' or)curl' are in the search path.
"
			exit 1
		fi
	fi
fi

[ "$debug" -ge 1 ] && echo WGET=$WGET
[ "$debug" -ge 1 ] && echo WGETOPTS=$WGETOPTS

mirror0=www.ams.org
mirror1=ams.rice.edu
mirror2=ams.impa.br
mirror3=ams.math.uni-bielefeld.de
mirror4=ams.mpim-bonn.mpg.de
mirror5=ams.u-strasbg.fr

mathscisite=$mirror0

tmpfile="/tmp/bibget.$(date +%N).tmp"

bibinputs=""

if [ "$BIBINPUTS" != "" ]; then
	for i in $(echo $BIBINPUTS | sed 's/:/ /'); do
		bibinputs="$(echo $i | grep $HOME | sed 's/[/]*$//')"
		[ "$bibinputs" != "" ] && break
	done
fi

if [ "$2" = "" -a "$1" = "-m" -o "$1" = "-l" -o "$1" = "--list" ]; then
	echo "
Some available MathSciNet mirrors:

$mirror0
$mirror1
$mirror2
$mirror3
$mirror4
$mirror5

Default is $mathscisite

Use with the \`-m' option:  bibget -m $mirror1 ...
"
	echo "Also checking  http://www.ams.org/errors/msn-mirrors.html for more..."
	$WGET $WGETOPTS http://www.ams.org/errors/msn-mirrors.html | grep http | grep mathscinet | sed 's/^.*http...//; s/.mathscinet.*//'
	exit 0
fi

usage() {
	echo "bibget, version $version: Command-line front-end for MathSciNet index.

GENERAL SEARCH:  bibget [ [ k=]keyword ] [ a=author ] [ t=title ] [ j=journal ]

  EXAMPLES:  bibget a=gilkey t=invariance book 1984
             bibget r=MR783634 >> books.bib

OTHER OPTIONS:
         [ -m mirror | --mirror mirror ] use alternative MathSciNet mirror
         [ -d | --debug ] debugging

OTHER USAGE:
  bibget [ r=MRnumber | -r MRnumber ]    grab a reference with given MRnumber
  bibget [ -m | -l | --list ]            list of some MathSciNet mirrors
  bibget [ -h | --help ]                this help

EXAMPLE OF SSH TUNNELING (via the institution subscribed to MathSciNet):
  ...no longer works. Try this instead:
  ssh fourier.math.tamu.edu \"bibget a=gilkey t=invariance book 1984\" 2>/dev/null

  (C) Andrew Comech, 2008--2012.  GNU General Public License.
"
}

if [ "$1" = "" -o "$1" = "-h" -o "$1" = "--help" ]; then
	usage
	exit 0
fi

filter() {
	sed 's/.refmr.*.endrefmr//; s/^.*endrefmr//' | sed 's/;[ ].*.refmr.*$//; s/.refmr.*$//' | grep -v "MRNUMBER.="
}

input0="^$1^$2^$3^$4^$5^$6^$7^$8^$9^"

[ "$debug" -ge 1 ] && echo input0=$input0

input=$(echo $input0 | sed 's/\^--debug//g;s/\^-d//g;s/--debug\^//g;s/-d\^//g')

if [ "$input0" != "$input" ]; then
	debug=1
fi

[ "$debug" -ge 1 ] && echo input0=$input0

[ "$debug" -ge 1 ] && echo WGET=$WGET, WGETOPTS=\"$WGETOPTS\"

[ "$debug" -ge 1 ] && echo input1=$input

input=$(echo $input | sed 's/-m\^/m=/g;s/--mirror\^/m=/g;s/-r\^/r=/g;s/-k\^/k=/g;s/-j\^/j=/g;s/-a\^/a=/g;s/-t\^/t=/g')

[ "$debug" -ge 1 ] && echo corrected input1="$input"

suggestedmirror=$(echo $input | sed 's/^.*\^m=//' | cut -f1 -d'^')

[ "$debug" -ge 1 ] && echo suggestedmirror="$suggestedmirror"

if [ "$suggestedmirror" != "" ]; then
	mathscisite="$suggestedmirror"
fi

input=$(echo $input | sed 's/\^m=[^\^]*\^/^/g')

input="$(echo $input | sed 's/[\^]*$//')"

[ "$debug" -ge 1 ] && echo input2=$input

fish="$(echo $input | cut -d'_' -f1 | sed 's/, /,%20/; s/,%20./&'*'/')"

output=""
if [ "$(echo $input | grep '._.')" != "" ]; then
	output="$(echo $input | sed 's/$/.bib/; s/\.bib\.bib/.bib/' | cut -d'_' -f2)"
fi

fish="$(echo $fish | sed 's/\^/^k=/g')"

[ "$debug" -ge 1 ] && echo fish0=$fish

fish="$(echo $fish | sed 's/\^k=a=/\&pg\^AUCN\&s\^/g' | sed 's/\^k=t=/\&pg\^TI\&s\^/g' |
	sed 's/\^k=k=/\&pg\^ALLF\&s\^/g' | sed 's/\^k=r=/\&pg\^MR\&s\^/g' | sed 's/\^k=j=/\&pg\^JOUR\&s\^/g' | sed 's/\^k=/\&pg\^ALLF\&s\^/g')"

[ "$debug" -ge 1 ] && echo fish1=$fish

fish="$(echo $fish | sed 's/^\^//')"

for i in 1 2 3 4 5 6 7 8 9; do
	fish="$(echo $fish | sed "s/\^/$i=/" | sed "s/\^/$i=/")"
done

fish="$fish&extend=1"

[ "$debug" -ge 1 ] && echo fish2=$fish

prefix="$mathscisite"/msnmain?fn=130\&fmt=bibtex\&l=100
[ "$debug" -ge 1 ] && echo prefix=$prefix

if [ "$debug" -ge 1 ]; then
	echo "Trying the following command:"
	echo $WGET $WGETOPTS http://"$prefix""$fish" | sed 's/&/\\&/g'
	echo " * * * Debugging mode (debug=$debug); will not filter the output! * * *"
	$WGET $WGETOPTS http://"$prefix""$fish"
else
	$WGET $WGETOPTS http://"$prefix""$fish" | sed '1,/<pre>/d; /<\/pre>/,/<pre>/d; /<\/pre>/,$ d' |
		sed 's/&lt;/</g;s/&gt;/>/g'
fi

exit
