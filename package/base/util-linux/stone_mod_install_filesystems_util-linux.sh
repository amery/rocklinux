#!/bin/bash
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/util-linux/stone_mod_install_util-linux.sh
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
#
# [INSTALLER] 10 mdadm ROCK Linux Operation System Installer V2 - util-linux partitioning module

PARTITIONING_MENU="${PARTITIONING_MENU} 'Partition disk using menu-based cfdisk' 'cfdisk DISK'
			'Partition disk using commandline based fdisk' 'fdisk DISK'
			'Dump partition table to file' 'utillinux_dump_sfdisk DISK'
			'Restore previously dumped partition table' 'utillinux_read_sfdisk DISK'"

MKFS_PROGRAMS="${MKFS_PROGRAMS} 'Create an SCO BFS Filesystem' 'mkfs.bfs PART'
			'Create a MINIX Filesystem' 'mkfs.minix PART'
			'Create a Swapspace' 'mkswap PART'"

utillinux_dump_sfdisk(){
	disk="${1}"
	gui_input "Please specify the filename to dump partition table to" "/tmp/${disk##*/}.partitiontable" "dump_path" 
	if [ -n "${dump_path}" ] ; then
		sfdisk --dump "${disk}" > "${dump_path}"
	fi
}

utillinux_read_sfdisk(){
	disk="${1}"
	gui_input "Please specify the filename to restore partition table from" "/tmp/${disk##*/}.partitiontable" "dump_path" 
	if [ -f "${dump_path}" ] ; then
		gui_yesno "WARNING! This will erase the existing partition table and CAN NOT be undone! Are you sure?"
		rval=${?}
		if [ ${rval} -eq 0 ] ; then
			sfdisk "${disk}" < "${dump_path}"
			echo -n "Press Return to continue."
			read
		fi
	else
		gui_message "File does not exist: ${dump_path}"
	fi
}
