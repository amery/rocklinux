#!/bin/bash

STAGE_2_BIG_IMAGE="2nd_stage.tar.gz"
STAGE_2_SMALL_IMAGE="2nd_stage_small.tar.gz"
STAGE_2_COMPRESS_ARG="--use-compress-program=gzip"

#640kB, err, 64 MB should be enought for the tmpfs ;-)
TMPFS_OPTIONS="size=67108864"

mod_load_info () { # {{{
	read os host version rest < <( uname -a )
	if [ -z "${os}" ] ; then
		echo "Can't run \`uname -a\`"
		return
	elif [ "${os}" != "Linux" ] ; then
		echo "Your operating system is not supported ?!"
		return
	fi

	mod_loader="/sbin/insmod"
	mod_dir="/lib/modules/"

	# kernel module suffix for <= 2.4 is .o, .ko if above
	if [ ${version:2:1} -gt 4 ] ; then
		mod_suffix=".ko"
		mod_suffix_len=3
	else
		mod_suffix=".o"
		mod_suffix_len=2
	fi
} # }}}
doboot() { # {{{
	if ! mkdir /mnt_root/old_root ; then
		echo "Can't create /mnt_root/old_root"
		exit_linuxrc=0
	fi

	if [ ! -f /mnt_root/linuxrc ] ; then
		echo "Can't find /mnt_root/linuxrc!"
		exit_linuxrc=0
	fi

	if [ ${exit_linuxrc} -ne 0 ] ; then
		if ! pivot_root "/mnt_root" "/mnt_root/old_root" ; then
			echo "Can't call pivot_root"
			exit_linuxrc=0
			return
		fi
		cd /

		if ! mount --move /old_root/dev /dev ; then
			echo "Can't remount /old_root/dev as /dev"
		fi

		if ! mount --move /old_root/proc /proc ; then
			echo "Can't remount /old_root/proc as /proc"
		fi

		if ! mount --move /old_root/sys /sys ; then
			echo "Can't remount /old_root/sys as /sys"
		fi

		if ! umount /old_root/tmp ; then
			echo "Can't umount /old_root/tmp"
		fi

	else
		rmdir /mnt_root/old_root || echo "Can't remove /mnt_root/old_root"

		umount /mnt_root || echo "Can't umount /mnt_root"
		rmdir  /mnt_root || echo "Can't remove /mnt_root"
	fi
} # }}}
trymount() { # {{{
	source=${1}
	target=${2}
	mount -t iso9600 -o ro ${source} ${target} && return 0
	mount -t ext3 -o ro ${source} ${target} && return 0
	mount -t ext2 -o ro ${source} ${target} && return 0
	mount -t minix -o ro ${source} ${target} && return 0
	mount -t vfat -o ro ${source} ${target} && return 0
	return -1
} # }}}
httpload() { # {{{
	echo -n "Enter base URL (e.g. http://1.2.3.4/rock): "

	read baseurl
	[ -z "${baseurl}" ] && return

	cat <<EOF
Select a stage 2 image file:

     0. ${STAGE_2_BIG_IMAGE}
     1. ${STAGE_2_SMALL_IMAGE}

EOF
	echo -n "Enter number or image file name (default=0): "
	read filename

	if [ -z "${filename}" ] ; then
		filename="${STAGE_2_BIG_IMAGE}"
	elif [ "${filename}" == "0" ] ; then
		filename=${STAGE_2_BIG_IMAGE}
	elif [ "${filename}" == "1" ] ; then
		filename="${STAGE_2_SMALL_IMAGE}"
	fi

	url="${baseurl%/}/${filename}"
	echo "[ ${url} ]"
	ROCK_INSTALL_SOURCE_URL=${baseurl}

	exit_linuxrc=1;
	if ! mkdir /mnt_root ; then
		echo "Can't create /mnt_root"
		exit_linuxrc=0
	fi

	if ! mount -t tmpfs -O ${TMPFS_OPTIONS} none /mnt_root ; then
		echo "Can't mount /mnt_root"
		exit_linuxrc=0
	fi

	wget -O - ${url} | tar ${STAGE_2_COMPRESS_ARG} -C /mnt_root -xf -

	echo "finished ... now booting 2nd stage"
	doboot
} # }}}
load_modules() { # {{{
# this starts the module loading shell
	directory=${1}
	cat <<EOF
module loading shell

you can navigate through the filestem with 'cd'. for loading a module
simply enter the shown name, to exit press enter on a blank line.

EOF
	cd ${directory}
	while : ; do
		echo "Directories:"
		count=0
		while read inode ; do
			[ -d "${inode}" ] || continue
			echo -n "	[	${inode}	]"
			count=$((${count}+1))
			if [ ${count} -gt 3 ] ; then
				echo
				count=0
			fi
		done < <( ls ) | expand -t1,3,19,21,23,39,41,43,59,61,63,78
		echo
		echo "Modules:"
		count=0
		while read inode ; do
			[ -f "${inode}" ] || continue
			[ "${inode%${mod_suffix}}" == "${inode}" ] && continue
			echo -n "	[	${inode%${mod_suffix}}	]"
			count=$((${count}+1))
			if [ ${count} -gt 3 ] ; then
				echo
				count=0
			fi
		done < <( ls ) | expand -t1,3,19,21,23,39,41,43,59,61,63,78
		echo
		echo -n "[${PWD##*/} ] > "
		read cmd par 
		if [ "${cmd}" == "cd" ] ; then
			cd ${par}
		elif [ -f "${cmd}${mod_suffix}" ] ; then
			insmod ${PWD%/}/${cmd}${mod_suffix} ${par}
		elif [ -z "${cmd}" ] ; then
			break
		else
			echo "No such module: ${cmd}"
		fi
	done
	return
} # }}}
getdevice () { # {{{
	cdroms="${1}"
	floppies="${2}"
	autoboot="${3}"
	devicelists="/dev/cdroms/* /dev/floppy/*"

	[ "${cdroms}" == "0" -a "${floppies}" == "0" ] && return -1

	devnr=0
	for dev in ${devicelists} ; do
		[ -e "${dev}" ] || continue
		[[ ${dev} = /dev/cdroms* ]] && [ "${cdroms}" == "0" ] && continue
		[[ ${dev} = /dev/floppy* ]] && [ "${floppies}" == "0" ] && continue

		eval "device_${devnr}='${dev}'"
		devnr=$((${devnr}+1))
	done

	[ ${devnr} -eq 0 ] && return -1
	
	x=0
	floppy=1
	cdrom=1
	while [ ${x} -lt ${devnr} ] ; do
		eval "device=\${device_${x}}"
		if [[ ${device} = /dev/cdrom* ]]  ; then
			echo "	${x}. CD-ROM #${cdrom} (IDE/ATAPI or SCSI)"
			cdrom=$((${cdrom}+1))
		fi
		if [[ ${device} = /dev/flopp* ]] ; then
			echo "	${x}. FDD (Floppy Disk Drive) #${floppy}"
			floppy=$((${floppy}+1))
		fi
		x=$((${x}+1))
	done

	echo -en "\nEnter number or device file name (default=0): "

	if [ ${autoboot} -eq 1 ] ; then
		echo "0"
		text=0
	else
		read text
	fi

	[ -z "${text}" ] && text=0

	while : ; do
		if [ -e "${text}" ] ; then
			devicefile="${text}"
			return 0
		fi

		eval "text=\"\${device_${text}}\""
		if [ -n "${text}" ] ; then
			devicefile="${text}"
			return 0
		fi

		echo -n "No such device found. Try again (enter=back): "
		read text
		[ -z "${text}" ] && return -1
	done
	
	return 1;
} # }}}
load_ramdisk_file() { # {{{
	autoboot=${1}

	echo -en "Select a device for loading the 2nd stage system from: \n\n"

	getdevice 1 1 ${autoboot} || return
	
	cat << EOF
Select a stage 2 image file:

	1. ${STAGE_2_BIG_IMAGE}
	2. ${STAGE_2_SMALL_IMAGE}
EOF
	echo -n "Enter number or image file name (default=1): "
	if [ ${autoboot} -eq 1 ] ; then
		echo "1"
		text=1
	else
		read text
	fi

	if [ -z "${text}" ] ; then
		filename="${STAGE_2_BIG_IMAGE}"
	elif [ "${text}" == "1" ] ; then
		filename="${STAGE_2_BIG_IMAGE}"
	elif [ "${text}" == "2" ] ; then
		filename="${STAGE_2_SMALL_IMAGE}"
	else
		filename="${text}"
	fi

	exit_linuxrc=1
	echo "Using ${devicefile}:${filename}."

	if ! mkdir -p /mnt_source ; then
		echo "Can't create /mnt_source"
		exit_linuxrc=0
	fi

	if ! mount ${devicefile} "/mnt_source" ; then
		echo "Can't mount /mnt_source"
		exit_linuxrc=0
	fi

	if ! mkdir -p /mnt_root ; then
		echo "Can't create /mnt_root"
		exit_linuxrc=0
	fi

	if ! mount -t tmpfs -o ${TMPFS_OPTIONS} none /mnt_root ; then
		echo "Can't mount tmpfs on /mnt_root"
		exit_linuxrc=0
	fi

	echo "Extracting 2nd stage filesystem to ram ..."
	if ! tar ${STAGE_2_COMPRESS_ARG} -C /mnt_root -xf /mnt_source/${filename} ; then
		echo "Can't extract /mnt/source/${filename}"
		exit_linuxrc=0
		return 1
	fi

	if ! umount "/mnt_source" ; then
		echo "Can't umount /mnt_source"
		exit_linuxrc=0
	fi

	if ! rmdir "/mnt_source" ; then
		echo "Can't remove /mnt_source"
		exit_linuxrc=0
	fi

	ROCK_INSTALL_SOURCE_DEV=${devicefile}
	ROCK_INSTALL_SOURCE_FILE=${filename}
	doboot
} # }}}
activate_swap() { # {{{
	echo
	echo -n "Enter file name of swap device: "

	read text
	if [ -n "${text}" ] ; then
		swapon ${text}
	fi
} # }}}
config_net() { # {{{
	ip addr
	echo
	ip route
	echo

	echo -n "Enter interface name (eth0): "
	read dv
	[ -z "${dv}" ] && dv="eth0"

	echo -n "Enter ip (192.168.0.254/24): "
	read ip
	[ -z "${ip}" ] && ip="192.168.0.254/24"

	ip addr add ${ip} dev ${dv}
	ip link set ${dv} up

	echo -n "Enter default gateway (none): "
	read gw
	[ -n "${gw}" ] && ip route add default via ${gw}

	ip addr
	echo
	ip route
	echo
} # }}}
autoload_modules () { # {{{
	while read cmd mod rest ; do
		[ -n "${rest}" ] && continue
		[ -z "${cmd}" ] && continue
		if [ "${cmd}" == "modprobe" -o "${cmd}" == "insmod" ] ; then
			echo "${cmd} ${mod}"
			${cmd} ${mod} 2>&1 >/dev/null
		fi
	done < <( /bin/gawk -f /bin/hwscan )
} # }}}
exec_sh() { # {{{
	echo "Quit the shell to return to the stage 1 loader!"
	/bin/sh
} # }}}
checkisomd5() { # {{{
	echo "Select a device for checking: "
	
	getdevice 1 0 0 || return
	echo "Running check..."

	/bin/checkisomd5 ${devicefile}

	echo "done"
	echo "Press Return key to continue."
	read
} # }}}

input=1
exit_linuxrc=0
[ -z "${autoboot}" ] && autoboot=0
mount -t ramfs none /dev || echo "Can't mount a ramfs on /dev"
mount -t sysfs none /sys || echo "Can't mount sysfs on /sys"
mount -t proc none /proc || echo "Can't mount /proc"
mount -t tmpfs -o ${TMPFS_OPTIONS} none /tmp || echo "Can't mount /tmpfs"
udevstart
cd /dev
rm -rf fd
ln -s /proc/self/fd
cd -
mod_load_info

autoload_modules
if [ ${autoboot} -eq 1 ] ; then
	load_ramdisk_file 1
fi
autoboot=0
cat << EOF
     ============================================
     ===   ROCK Linux 1st stage boot system   ===
     ============================================

The ROCK Linux install / rescue system boots up in two stages. You
are now in the first of this two stages and if everything goes right
you will not spend much time here. Just load your SCSI and networking
drivers (if needed) and configure the installation source so the
2nd stage boot system can be loaded and you can start the installation.
EOF
while [ ${exit_linuxrc} -eq 0 ] ; do
	cat <<EOF
	0. Load 2nd stage system from local device
	1. Load 2nd stage system from network
	2. Configure network interfaces (IPv4 only)
	3. Load kernel modules from this disk
	4. Load kernel modules from another disk
	5. Activate already formatted swap device
	6. Execute a shell (for experts!)
	7. Validate a CD/DVD against its embedded checksum

EOF
	echo -n "What do you want to do [0-7] (default=0)? "
	read text
	[ -z "${text}" ] && text=0
	input=${text//[^0-9]/}

	
	case "${input}" in
		0)
		  load_ramdisk_file 0
		  ;;
		1)
		  httpload
		  ;;
		2)
		  config_net
		  ;;
		3)
		  load_modules "${mod_dir}"
		  ;;
		4)
		  mkdir "/mnt_floppy" || echo "Can't create /mnt_floppy"
		  trymount "/dev/floppy/0" "/mnt_floppy" && load_modules "/mnt_floppy"
		  umount "/mnt_floppy" || echo "Can't umount /mnt_floppy"
		  rmdir "/mnt_floppy" || echo "Can't remove /mnt_floppy"
		  ;;
		5)
		  activate_swap
		  ;;
		6)
		  exec_sh
		  ;;
		7)
		  checkisomd5
		  ;;
		*)
		  echo "No such option present!"
	esac
done
	
exec /linuxrc
echo "Can't start /linuxrc!! Life sucks.\n\n"
