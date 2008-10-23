#!/bin/sh
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/misc/archive/treenice.sh
# ROCK Linux is Copyright (C) 1998 - 2006 Clifford Wolf
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

main() {
	renice $newpriority -p $1 | sed "s,^,$2,"
	# for y in `ps -e -o ppid,pid | grep "^ *$1 " | sed "s,^ *$1 ,,"`
	for y in `cut -f1,4 -d' ' /proc/[0-9]*/stat | grep " $1\$" | cut -f1 -d' '`
	do main $y "$2  " ; done
}

newpriority=$1
shift

if [ $# = 0 ] ; then
	echo "Usage: $0 <new priority> <pid> [ <pid> [ ... ] ]"
	exit 1
else
	for x ; do
		for y in $( ps -e -o pid,comm | tail -n +2 |
			awk "\$1 == \"$x\" || \$2 == \"$x\" { print \$1; }" )
		do
				main $y ""
		done
	done
fi

exit 0
