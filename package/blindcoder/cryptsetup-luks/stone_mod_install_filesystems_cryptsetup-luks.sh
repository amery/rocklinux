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
# [INSTALLER] 10 cryptsetup-luks ROCK Linux Operation System Installer V2 - cryptsetup-luks partitioning module

MKFS_PROGRAMS="${MKFS_PROGRAMS} 'Create/Edit Encryption using LUKS' 'cryptsetupluks_create_mapping PART'"
POSTINSTALL_BEFORE_CHROOT="${POSTINSTALL_BEFORE_CHROOT} cryptsetupluks_before_chroot"
ADDITIONAL_DISK_DETECTOR="${ADDITIONAL_DISK_DETECTOR} cryptsetup_luks_disk_detector"
touch /tmp/cryptsetup_luks

cryptsetupluks_before_chroot(){
	mkdir -p /mnt/target/etc/conf/luks/
	cp /tmp/cryptsetup_luks /mnt/target/etc/conf/luks/mounts
}

cryptsetup_luks_disk_detector() {
# we'll go the mdadm way and just loop through /proc/partitions
	DISKS="${DISKS} '' '' 'Encrypted Filesystems' ''"
	while read major minor blocks name ; do
		[ -z "${name}" -o "${name}" == "name" ] && continue
		read disk < <( find /dev -name ${name} )
		[ -z "${disk}" ] && continue
		disktype "${disk}" | grep -q RAID && continue # if it's a RAID partition, the encryption is on the RAID metadevice, not on the physical device
		if cryptsetup isLuks "${disk}" >/dev/null 2>&1 ; then
			encname="${disk#/}"
			encname="${encname//\//_}"
			encname="${encname#_}"
			[ -b /dev/mapper/${encname} ] || continue
			DISKS="${DISKS} 'Encryption on ${disk}' ''"
			main_setup_filesystems_add_part "/dev/mapper/${encname}"
		fi
	done < /proc/partitions
}

cryptsetupluks_delkey(){
	local disk="${1}"
	
#Key Slot 0: ENABLED
	local menu=""
	cryptsetup luksDump | grep ENABLED | while read key slot number enabled ; do
		number="${number%:}"
		menu="${menu} 'Delete Key ${number}' 'cryptsetup luksDelKey ${disk} ${number}'; return 1'"
	done
	while eval gui_menu CRYPTSETUP_LUKS_DEL_KEY "'Delete a Key from LUKS'" ${menu} ; do : ; done
}

cryptsetupluks_luksclose(){
	local disk="${1}"

	cryptsetup luksClose "${disk}"
	tmp="$(mktemp)"
	grep -v "^${disk}" /tmp/cryptsetup_luks > "${tmp}"
	mv "${tmp}" /tmp/cryptsetup_luks
}

cryptsetupluks_luksopen(){
	local disk="${1}"
	local encname="${2}"

	if cryptsetup luksOpen "${disk}" "${encname}" ; then
		echo "${disk}	encrypted" >> /tmp/cryptsetup_luks
	fi
}

cryptsetupluks_edit_mapping(){
	local disk="${1}"
	encname="${disk#/}"
	encname="${encname//\//_}"
	encname="${encname#_}"
	
	while : ; do
		local menu
		if [ -b /dev/mapper/${encname} ] ; then
			menu="'Add a new key' 'cryptsetup luksAddKey ${disk}'
				'Delete a key' 'cryptsetupluks_delkey ${disk}'"
			menu="${menu} 'Close this mapping' 'cryptsetupluks_luksclose ${encname};'"
		else
			menu="${menu} 'Open this mapping' 'cryptsetupluks_luksopen ${disk} ${encname};'"
		fi
		menu="${menu} 'Dump LUKS information' 'cryptsetup luksDump ${disk}; echo -n Press Enter to continue; read'"
		eval gui_menu CRYPTSETUP_LUKS_EDIT_MAPPING "'Edit LUKS mapping ${disk}'" ${menu}
		[ ${?} -eq 1 ] && break # Cancel
	done
}

cryptsetupluks_create_mapping(){
	local disk="${1}"

	if cryptsetup isLuks "${disk}" >/dev/null 2>&1 ; then
		cryptsetupluks_edit_mapping "${disk}"
	else
		encname="${disk#/}"
		encname="${encname//\//_}"
		encname="${encname#_}"
		if cryptsetup luksFormat "${disk}" ; then
			cryptsetupluks_luksopen "${disk}" "${encname}"
		fi
	fi
}
