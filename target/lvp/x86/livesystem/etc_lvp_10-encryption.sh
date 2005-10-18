#!/bin/bash

encryption_start() {
	if [ -e /lvp.data1 ] ; then
		numfiles=0
		files=""
		echo -n "Found "
		for x in /lvp.data* ; do
			echo -n "${x} "
			numfiles=$(( ${numfiles} + 1 ))
			files="${files} /dev/loop/${numfiles}"
		done
		echo
		echo "Starting crypto-subroutine"

		exec 2>/dev/null
		for x in /lvp.data* ; do
			losetup /dev/loop/${x#/lvp.data} ${x} 
		done
		mdadm --build /dev/md/0 -l linear --force -n ${numfiles} ${files} 
		while [ ! -e /mnt1/lvp.xml ] ; do
			echo -n "Please enter passphrase: "
			read -s pass
			echo
			pass="`echo ${pass} | md5sum`"
			pass=${pass%% *}
			echo 0 `/sbin/blockdev --getsize /dev/md/0` crypt aes-plain ${pass} 0 /dev/md/0 0 | /sbin/dmsetup create lvp_data
			mount /dev/mapper/lvp_data /mnt1
			if [ ! -e /mnt1/lvp.xml ] ; then
				echo "Wrong Passphrase!"
				dmsetup remove /dev/mapper/lvp_data
			fi
		done
		exec 2>&1
	fi
}

encryption_stop(){
	umount /mnt1
	dmsetup remove /dev/mapper/lvp_data
	mdadm -S /dev/md/0
	for x in /lvp.data* ; do
		losetup -d /dev/loop/${x#/lvp.data}
	done
}

encryption_(){
	echo "Uh-Oh"
}

eval "encryption_${1}"
