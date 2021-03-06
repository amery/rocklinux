#!/bin/sh
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/less/lesspipe.sh
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

case "$1" in
	# Archives
	*.a) ar t $1;;
	*.tar) tar tvf $1;;
	*.tgz|*.tar.gz|*.tar.[Zz]) tar tvfz $1;;
	*.tbz2|*.tar.bz2) tar tvfI $1;;
	*.zip) unzip -l $1;;
	# Packages
	*.gem) mine -p $1 ; echo -e "\nFile List:" ; mine -l $1;;
	*.rpm) rpm -q -i -p $1 ; echo "File List   :" ; rpm -q -l -p $1;;
	# Manuals
	*ld.so.8) nroff -p -t -c -mandoc $1;;
	*.so.*) ;;
	*.[1-9]|*.[1-9][mxt]|*.[1-9]thr|*.man)
		nroff -p -t -c -mandoc $1;;
	# Compressed manuals
	*.[1-9].gz|*.[1-9][mxt].gz|*.[1-9]thr.gz|*.man.gz|\
	*.[1-9].[Zz]|*.[1-9][mxt].[Zz]|*.[1-9]thr.[Zz]|*.man.[Zz])
		gzip -c -d $1 | nroff -p -t -c -mandoc;;
	*.[1-9].bz2|*.[1-9][mxt].bz2|*.[1-9]thr.bz2|*.man.bz2)
		bzip2 -c -d $1 | nroff -p -t -c -mandoc ;;
	# Compressed files
	*.gz|*.Z|*.z) gzip -c -d $1;;
	*.bz2) bzip2 -c -d $1;;
esac
