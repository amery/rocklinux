#!/bin/bash
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/mdadm/stone_mod_install_mdadm.sh
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
# [INSTALLER] 10 mdadm ROCK Linux Operation System Installer V2 - mdadm RAID module

DISKS_MENU="${DISKS_MENU} 'Setup Software-RAID' 'mdadm_setup_software_raid'"
ADDITIONAL_DISK_DETECTOR="${ADDITIONAL_DISK_DETECTOR} mdadm_disk_detector"

mdadm_setup_software_raid_new(){ # {{{
	local level=""
	local menu=""

	for x in 1 2 3 4 5 6 0 ; do
		menu="${menu} 'Level ${x}' 'level=${x}'"
	done
	eval gui_menu MENU_mdadm_setup_software_raid_new "'Select RAID Level'" ${menu}
	[ -z "${level}" ] && return
	
	local selected=""
	local all=""
	local oldselected=""
	while : ; do
		local end=0
		menu=""
		read selected < <( sed -e 's,^ *,,g' -e 's, *$,,g' -e 's,  *, ,g' <<< "${selected}" )
		while read major minor blocks name ; do
# TODO XXX This really needs different handling, eg everything on the DEVICES line of /etc/mdadm.conf, but this will suffice for the time being
			[ "${name}" == "name" ] && continue
			[ -z "${name}" ] && continue
			if [[ ${selected} = ${name} || ${selected} = *\ ${name}\ * || ${selected} = *\ ${name} || ${selected} = ${name}\ * ]] ; then
				menu="${menu} '[X] ${name} ($((${blocks}/1024)) MB)'"
				menu="${menu} 'selected=\"\$( sed -e \"s,${name} , ,g\" -e \"s,${name}\$,,g\" <<< \"${selected}\" )\"'"
			else
				menu="${menu} '[ ] ${name} ($((${blocks}/1024)) MB)'"
				menu="${menu} 'selected=\"${selected} ${name}\"'"
			fi
		done < /proc/partitions
		eval gui_menu MENU_mdadm_setup_software_raid_new "'Select Partitions to use in the array'" ${menu} "'Build Array!' 'end=1'"
		[ "${end}" == "1" ] && break
		[ "${selected}" == "${oldselected}" ] && return # indicates 'Cancel'
		oldselected="${selected}"
	done

	tmp="$(mktemp)"
	mdadm -Ebsc partitions > "${tmp}"
	for x in `seq 0 255` none ; do
		grep -q 'md/\?'"${x}" "${tmp}" || break
	done
	rm -f "${tmp}"

	if [ "${x}" == "none" ] ; then
		gui_message "There is no free RAID device available!"
		return
	fi

	gui_yesno "Really create /dev/md/${x} from disks ${selected}? All data on the disks will be deleted!"
	rval=${?}
	if [ ${rval} -eq 0 ] ; then
		mdadm -C /dev/md/${x} -l ${level} -n $( wc -w <<< "${selected}" ) \
		    --auto=yes --symlink=yes $(
			for x in ${selected} ; do 
				find /dev -name ${x} -type b
			done )
		echo "Remember to recreate /etc/mdadm.conf!"
		read -p "Press enter to continue"
	fi
} # }}}

mdadm_setup_software_raid(){
#/etc/mdadm.conf:
#DEVICE partitions
#MAIL root@localhost
#
#ARRAY /dev/md0 level=raid1 num-devices=4 UUID=3559ffcf:14eb9889:3826d6c2:c13731d7
#ARRAY /dev/md1 level=raid5 num-devices=4 UUID=649fc7cc:d4b52c31:240fce2c:c64686e7
#ARRAY /dev/md2 level=raid5 num-devices=4 UUID=9a3bf634:58f39e44:27ba8087:d5189766
#ARRAY /dev/md3 level=raid5 num-devices=4 UUID=719401e0:65d2e3bf:aabaa5cd:79bdde46
#ARRAY /dev/md4 level=raid5 num-devices=4 UUID=d4799be3:5b157884:e38718c2:c05ab840
#ARRAY /dev/md5 level=raid5 num-devices=4 UUID=ca4a6110:4533d8d5:0e2ed4e1:2f5805b2

	local menu
	while : ; do
		menu="'Recreate /etc/mdadm.conf' 'echo DEVICE partitions > /etc/mdadm.conf; mdadm -Ebs >> /etc/mdadm.conf; REREAD_INFORMATION=1'"
		menu="${menu} 'Start all RAIDs in /etc/mdadm.conf' 'mdadm -As --auto=yes --symlink=yes; REREAD_INFORMATION=1'"
		menu="${menu} 'Create a new RAID' 'mdadm_setup_software_raid_new'"
		menu="${menu} 'Existing Arrays in /etc/mdadm.conf:' ''"
		while read ARRAY dev rest ; do
			level="${rest#*level=}"
			level="${level%% *}"
			level="${level:-unknown}"
			menu="${menu} '${dev} (RAID level ${level})' ''"
#md5 : active raid5 hdb8[0] hdf8[3] hdc8[2] hda8[1]
			read line < <( grep '^md/\?'"${dev##*md}" /proc/mdstat )
			line="${line#*:}"
			read status level devices <<< "${line}"
			menu="${menu} ' Devices: ${devices}' ''"
		done < <( grep ^ARRAY /etc/mdadm.conf )
		eval gui_menu MENU_mdadm_setup_software_raid "'RAID Configuration (mdadm)'" ${menu}
		[ "${?}" == "1" ] && break	# Cancel was pressed
	done
}

mdadm_disk_detector(){
	export DISKS="${DISKS} '' '' 'Software RAID Devices' ''"
	tmp="$( mktemp )"
	[ -e /etc/mdadm.conf ] || return
	cat /etc/mdadm.conf > "${tmp}"
# ARRAY /dev/md1 level=raid5 num-devices=4 UUID=649fc7cc:d4b52c31:240fce2c:c64686e7
	while read ARRAY md level numdev uuid ; do
		[ "${ARRAY}" != "ARRAY" ] && continue
		level="${level#*=}"
		numdev="${numdev#*=}"
		uuid="${uuid#*=}"
		active=""
		size=0
		fstype="Unknown"
		tmp2="$(mktemp)"
		mdadm -Q --detail "${md}" > "${tmp2}"
		if grep -q "${uuid}" "${tmp2}" ; then
			active="(active)"

			tmp3="$(mktemp)"
			disktype "${md}" > "${tmp3}"

			read fstype rest < <( grep " file system" "${tmp3}" )
			grep -q "^Linux swap" "${tmp3}" && fstype="Swap"
			fstype="${fstype:-Unknown}"

			size="$(blockdev --getsize64 ${md})"
			rm -f "${tmp3}"
		fi
		rm -f "${tmp2}"
		export DISKS="${DISKS} '${md}${active:+ }${active} RAID Level ${level#raid}, ${numdev} devices, $(( ${size} / 1024 / 1024 )) MB' 'mdadm_edit_raid ${uuid}'"
		export DISKS="${DISKS} ' ${fstype} Filesystem' 'main_edit_part ${md}'"
		mountpoint="$( mount | grep ^${md} | cut -f3 -d' ')"
		[ -n "${mountpoint}" ] && mountpoint="${mountpoint}/";
		mountpoint="${mountpoint#/mnt/target}"
		[ -n "${mountpoint}" ] && mountpoint="/${mountpoint#/}"	# necessary to do this way because rootfs will be "/mnt/target"
		if [ -L "${md}" ] ; then
			realdisk="$( readlink -f ${md} )"
		else
			realdisk="${md}"
		fi
		swapon -s | grep -q ^${realdisk} && mountpoint="SWAP"
		if [ -z "${mountpoint}" ] ; then
			if [ "${fstype}" == "Swap" ] ; then
				export DISKS="${DISKS} '  Inactive Swap'"
			elif [ "${fstype}" == "RAID" ] ; then
				export DISKS="${DISKS} '  Part of a RAID'"
			else
				export DISKS="${DISKS} '  Not mounted'"
			fi
		elif [ "${mountpoint}" == "SWAP" ] ; then
			export DISKS="${DISKS} '  Active Swapspace'"
		else
			export DISKS="${DISKS} '  Mounted on ${mountpoint}'"
		fi
		export DISKS="${DISKS} 'main_mount_partition \"${md}\" \"${mountpoint:-nowhere}\" \"${fstype}\"'"
	done < "${tmp}"

	rm -f "${tmp}"
}
