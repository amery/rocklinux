#!/bin/sh
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/misc/archive/killport.sh
# ROCK Linux is Copyright (C) 1998 - 2005 Clifford Wolf
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

signal=15
returncode=0

for port ; do
	xport="`printf '%04X' $port 2> /dev/null || echo ERROR`"
	if [ "$xport" = "ERROR" ] ; then
		echo "Not a valid port number: $port" >&2
		returncode=$(($returncode + 1))
	else
	    echo "Sending signal $signal to all processes connected" \
	         "to port $port:"

	    for proto in tcp udp ; do
		echo -n "  Inodes for `echo $proto | tr a-z A-Z`/$xport: "
		inodes=`egrep "^ *[0-9]+: +[0-9A-F]+:$xport " /proc/net/$proto |
		       tr -s ' ' | cut -f11 -d' ' | tr '\n' ' '`
		if [ "$inodes" ] ; then
		    echo "$inodes (getting pids)"
		    for inode in $inodes ; do
			echo -n "    PIDs for inode $inode: "
			pids="`ls -l /proc/[0-9]*/fd/* 2> /dev/null | \
			       grep 'socket:\['$inode'\]' | tr -s ' ' |
			       cut -f9 -d' ' | cut -f3 -d/ | tr '\n' ' '`"
			if [ "$pids" ] ; then
				echo "$pids (sending signal)"
				kill -$signal $pids
			else
				echo "None found."
			fi
		    done
		else
			echo "None found."
		fi
	    done
	fi
done

exit $returncode
