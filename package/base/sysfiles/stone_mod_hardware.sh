# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/sysfiles/stone_mod_hardware.sh
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
# [MAIN] 20 hardware Kernel Drivers and Hardware Configuration

get_module_dependencies() {
        module="${1}"
        deps=`/sbin/modinfo -F depends ${module} 2>/dev/null | tr ',' ' '`
        if [ -n "${deps}" ] ; then
                for dep in ${deps} ; do
                        echo "`get_module_dependencies ${dep}`"
                done
        fi
        echo "${module}";
}

get_initrd_module_cmds() {
	ret=""
	modules=`grep '^modprobe ' /etc/conf/kernel | grep -v 'no-initrd' | \
                sed 's,[        ]#.*,,' | \
                while read a b c; do
			echo "${b}"
		done`

	for module in ${modules} ; do
		module_dependencies=`get_module_dependencies ${module} | sort | uniq`
		
		if [ -n "${module_dependencies}" -a "${module_dependencies}" != "${module}" ] ; then
			ret="$ret '${module} (adds: ${module_dependencies})' 'remove_module_from_initrd \"${module}\"'"
		else
			ret="$ret '${module}' 'remove_module_from_initrd \"${module}\"'"
		fi
	done
	echo ${ret}

}

add_module_to_initrd() {
	gui_input "Module to add to initrd: " "" "addmodule"
	[ -z "${addmodule}" ] && return;

	kernel=`uname -r`
	module="`find /lib/modules/${kernel} -name "${addmodule}.o" -o -name "${addmodule}.ko" 2>/dev/null`"
	if [ -z "${module}" ] ; then
		gui_message "Error: No such module in /lib/modules/$kernel!";
	else 
		echo "modprobe ${addmodule}" >> /etc/conf/kernel
	fi
	recreate_initrd=1
}

remove_module_from_initrd() {
	module=${1};
	grep -v '^modprobe[ 	].*'${module} /etc/conf/kernel > /etc/conf/kernel.new
	mv /etc/conf/kernel.new /etc/conf/kernel
	recreate_initrd=1
}

set_dev_setup() {
    echo "devtype=$1" > /etc/conf/devtype
}

store_clock() {
	if [ -f /etc/conf/clock ] ; then
		sed -e "s/clock_tz=.*/clock_tz=$clock_tz/" \
		    -e "s/clock_rtc=.*/clock_rtc=$clock_rtc/" \
		  < /etc/conf/clock > /etc/conf/clock.tmp
		grep -q clock_tz= /etc/conf/clock.tmp || \
		  echo clock_tz=$clock_tz >> /etc/conf/clock.tmp
		grep -q clock_rtc= /etc/conf/clock.tmp || \
		  echo clock_rtc=$clock_rtc >> /etc/conf/clock.tmp
		mv /etc/conf/clock.tmp /etc/conf/clock
	else
		echo -e "clock_tz=$clock_tz\nclock_rtc=$clock_rtc\n" \
		  > /etc/conf/clock
	fi
	if [ -w /proc/sys/dev/rtc/max-user-freq -a "$clock_rtc" ] ; then
		echo $clock_rtc > /proc/sys/dev/rtc/max-user-freq
	fi
}

set_zone() {
	clock_tz=$1
	hwclock --hctosys --$clock_tz
	store_clock
}

set_rtc() {
	gui_input "Set new enhanced real time clock precision" \
                  "$clock_rtc" "clock_rtc"
	store_clock
}

main() {
    while
	devtype=udev
	if [ -f /etc/conf/devtype ]; then
	    . /etc/conf/devtype
	fi

	clock_tz=utc
	clock_rtc="`cat /proc/sys/dev/rtc/max-user-freq 2> /dev/null`"
	if [ -f /etc/conf/clock ]; then
	    . /etc/conf/clock
	fi

	cmd="gui_menu hw 'Kernel Drivers and Hardware Configuration'"

	for x in devfs udev static; do
	    if [ "$devtype" = $x ]; then
	        cmd="$cmd \"<*> Use $x /dev filesystem.\""
	    else
	        cmd="$cmd \"< > Use $x /dev filesystem.\""
	    fi
	    cmd="$cmd \"set_dev_setup $x\"";
	done
	cmd="$cmd '' ''";

	# initrd module handling
        cmd="$cmd 'Add module to initrd' 'add_module_to_initrd'";
	cmd="$cmd '' ''";
	cmd="$cmd 'Current initrd modules, select to remove: ' ''";
	cmd="$cmd `get_initrd_module_cmds`";
     
	cmd="$cmd '' ''";
	cmd="$cmd 'Force initrd re-creation now' '/sbin/mkinitrd; recreate_initrd=0'";
	cmd="$cmd '' ''";

	if [ "$clock_tz" = localtime ] ; then
	    cmd="$cmd '[*] Use localtime instead of utc' 'set_zone utc'"
	else
	    cmd="$cmd '[ ] Use localtime instead of utc' 'set_zone localtime'"
	    clock_tz=utc
	fi
	cmd="$cmd 'Set enhanced real time clock precision ($clock_rtc)' set_rtc"
 
	eval "$cmd"
    do : ; done

    return
}

