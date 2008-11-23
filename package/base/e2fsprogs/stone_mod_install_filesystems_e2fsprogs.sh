#!/bin/bash
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/e2fsprogs/stone_mod_install_e2fsprogs.sh
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
# [INSTALLER] 10 mdadm ROCK Linux Operation System Installer V2 - e2fsprogs partitioning module

# Use an inode size of 128 bytes (-I 128) for now since grub does not find files on
# file systems created with the new default value 256. Instead grub would print
# an error when installing the bootloader:
#	Checking if "/boot/grub/stage1" exists... no
#	Checking if "/grub/stage1" exists... no
#
#	Error 15: File not found

MKFS_PROGRAMS="${MKFS_PROGRAMS} 'Create an Ext2 Filesystem' 'mkfs.ext2 -I 128 PART'
				'Create an Ext3 Filesystem' 'mkfs.ext3 -I 128 PART'"