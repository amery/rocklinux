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

		echo "Please choose which encryption you want to use:"
		echo -e "\t1\tblowfish"
		echo -e "\t2\ttwofish"
		echo -e "\t3\tserpent"
		echo
		unset thisenc
		while [ -z "${thisenc}" ] ; do
			read -p "Please enter your choice: " rthisenc
			[ "${rthisenc}" == "1" ] && thisenc="blowfish256"
			[ "${rthisenc}" == "2" ] && thisenc="twofish256"
			[ "${rthisenc}" == "3" ] && thisenc="serpent256"
		done
		echo "Using ${thisenc%256} encryption."

		exec 2>/dev/null
		while [ ! -e /mnt1/lvp.xml ] ; do
			read -p "Please enter passphrase: " -s passphrase
			echo
			for x in /lvp.data* ; do
				echo "${passphrase}" | losetup -e ${thisenc} -p 0 /dev/loop/${x#/lvp.data} ${x} 
			done
			mdadm --build /dev/md/0 -l linear -n ${numfiles} ${files} 
			mount /dev/md/0 /mnt1
			if [ ! -e /mnt1/lvp.xml ] ; then
				echo "Wrong Passphrase!"
				mdadm /dev/md/0 -S
				for x in /lvp.data* ; do
					losetup -d /dev/loop/${x#/lvp.data}
				done
			fi
		done
		exec 2>&1
	fi
}

encryption_stop(){
	exec 2>/dev/null
	umount /mnt1
	mdadm /dev/md/0 -S
	for x in /lvp.data* ; do
		losetup -d /dev/loop/${x#/lvp.data}
	done
	exec 2>&1
}

encryption_(){
	echo "Uh-Oh"
}

eval "encryption_${1}"
