#!/bin/sh
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/x86/cpuburn/cpuburn.sh
# ROCK Linux is Copyright (C) 1998 - 2003 Clifford Wolf
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. A copy of the GNU General Public
# License can be found at Documentation/COPYING.
# 
# Many people helped and are helping developing ROCK Linux. Please
# have a look at http://www.rocklinux.org/ and the Documentation/TEAM
# file for details.
# 
# --- ROCK-COPYRIGHT-NOTE-END ---

errors=`mktemp -t cpuburn.XXXX`
start=`date "+%s"` ; command="" ; jobs=1

help() {
	cat << 'EOT'

Usage: $0 [ -j Jobs ] { -k6 | -k7 | -p5 | -p6 | -bx | -mmx } [ -mem Mem ]

The -mem option is only available for the bx and mmx tests. Possible values
for Mem are: 2kb, 4kb, 8kb, 16kb, 32kb, 64kb, 128kb, 256kb, 512kb, 1MB, 2MB,
4MB, 8MB, 16MB, 32MB and 64MB.

EOT
	rm $errors
	exit 1
}

while [ "$#" != 0 ]
do
	case "$1" in
	    -j)
		jobs=$2 ; shift ;;

	    -bx)
		command="burnBX" ;;
	    -k6)
		command="burnK6" ;;
	    -k7)
		command="burnK7" ;;
	    -mmx)
		command="burnMMX" ;;
	    -p5)
		command="burnP5" ;;
	    -p6)
		command="burnP6" ;;

	    -mem)
		[ "$command" != burnBX -a "$command" != burnMMX ] && help

		case "$2" in
		    2kb)
			command="$command A" ;;
		    4kb)
			command="$command B" ;;
		    8kb)
			command="$command C" ;;
		    16kb)
			command="$command D" ;;
		    32kb)
			command="$command E" ;;
		    64kb)
			command="$command F" ;;
		    128kb)
			command="$command G" ;;
		    256kb)
			command="$command H" ;;
		    512kb)
			command="$command I" ;;
		    1MB)
			command="$command J" ;;
		    2MB)
			command="$command K" ;;
		    4MB)
			command="$command L" ;;
		    8MB)
			command="$command M" ;;
		    16MB)
			command="$command N" ;;
		    32MB)
			command="$command O" ;;
		    64MB)
			command="$command P" ;;
		    *)
			help ;;
		esac
		shift
		;;

	    *)
		help ;;
	esac
	shift
done

[ "$command" = "" ] && help
desc="${jobs}x ${command#burn}"

while [ $jobs -gt 0 ] ; do
	(
		PATH=".:$PATH"
		while true ; do
			eval "$command"
			date "+%T - $?" >> $errors
		done
	) &
	jobs=$(( $jobs - 1 ))
done &> /dev/null

trap "fuser -9 -k $errors > /dev/null ; rm $errors ; exit 0" INT TERM
echo "Using temp file $errors ..."

while true
do
	tm=$(( `date +%s` - $start ))
	tm=$( printf '%02d:%02d:%02d:%02d'	\
		$(( ($tm / (60*60*24)) ))	\
		$(( ($tm / (60*60)) % 24 ))	\
		$(( ($tm / 60) % 60 ))		\
		$((  $tm % 60 )) )
	echo `date "+%T ($tm)"` " [$desc] " Load average: \
	     `uptime | sed "s,.*average: ,,"`, "" `wc -l < $errors` Errors.
	sleep 5
done

