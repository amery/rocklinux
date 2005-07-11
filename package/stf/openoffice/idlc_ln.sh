#! /bin/bash

dmake > test.txt 2>&1
LNDIR="`sed -n test.txt -e"s,ERROR: [a-zA-Z0-9 ]* /[^/]*/[^/]*\(.*\),\1,gp"`"
LN2DIR="`echo $LNDIR | sed -n -e"s,/[^/]*,/..,gp"`"
IDLC="`grep test.txt -e"idlc: compile"`"
while [ "$IDLC" != "" ];
do
	echo \"$LNDIR\" \"$LN2DIR\" \"$IDLC\"
	ln -svf ./$LN2DIR/solver/645/unxlngi4.pro/bin/idlcpp ./$LNDIR/idlcpp
	dmake > test.txt 2>&1
	LNDIR="`sed -n test.txt -e"s,ERROR: [a-zA-Z0-9 ]* /[^/]*/[^/]*\(.*\),\1,gp"`"
	LN2DIR="`echo $LNDIR | sed -n -e"s,/[^/]*,/..,gp"`"
	IDLC="`grep test.txt -e"idlc: compile"`"
done
