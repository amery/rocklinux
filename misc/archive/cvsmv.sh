#!/bin/sh
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/misc/archive/cvsmv.sh
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

if [ "$1" = "rm" ] ; then
	find $2 -type f ! -path '*/CVS/*' | xargs rm -vf
elif [ "$1" = "mv" -o "$1" = "cp" ] ; then
	find $2 -type d ! -name CVS -printf "$3/%P\n" | xargs mkdir -p
	find $2 -type f ! -path '*/CVS/*' -printf "$1 -v %p $3/%P\n" | sh
else
	echo "Usage: $0 mv source-dir target-dir"
	echo "Usage: $0 cp source-dir target-dir"
	echo "   or: $0 rm remove-dir"
	exit 1
fi

