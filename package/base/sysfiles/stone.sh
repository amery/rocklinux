#!/bin/bash
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/sysfiles/stone.sh
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

export SETUPD="${SETUPD:-/etc/stone.d}"
export SETUPG="${SETUPG:-dialog}"
export STONE="`type -p $0`"

if [ "$1" = "-text"   ] ; then SETUPG="text"   ; shift ; fi
if [ "$1" = "-dialog" ] ; then SETUPG="dialog" ; shift ; fi
if [ "$1" = "-x11"    ] ; then SETUPG="x11"    ; shift ; fi

. ${SETUPD}/gui_${SETUPG}.sh

if [ "$1" -a -f "${SETUPD}/mod_$1.sh" ]
then
	. ${SETUPD}/mod_$1.sh ; shift
	if [ -z "$*" ] ; then
		main
	else
		eval "$*"
	fi
elif [ "$#" = 0 -a -f ${SETUPD}/default.sh ]
then
	. ${SETUPD}/default.sh
elif [ "$#" = 0 ]
then
	while
		command="gui_menu main 'Main Menu - Select the Subsystem you want to configure'"
		while read a b c cmd name ; do
			x="'" ; cmd="${cmd//,/ }"
			command="$command '${name//$x/$x\\$x$x}'"
			command="$command '$STONE ${cmd//$x/$x\\$x$x}'"
		done < <( grep -h '^# \[MAIN\] [0-9][0-9] ' $SETUPD/* | sort )
		eval "$command"
	do : ; done
else
	echo
	echo "STONE - Setup Tool ONE - ROCK Linux System Configuration"
	echo
	echo "Usage: $0 [ -text | -dialog | -x11 ] [ module [ command ] ]"
	echo
fi

