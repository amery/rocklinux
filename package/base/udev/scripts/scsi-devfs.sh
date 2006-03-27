#!/bin/bash
#
#  scsi-devfs.sh: udev external PROGRAM script
#
#  Copyright 2004  Richard Gooch <rgooch@atnf.csiro.au>
#  Copyright 2004  Fujitsu Ltd.
#  Distributed under the GNU Copyleft version 2.0.
#
# return devfs-names for scsi-devices
# Usage in udev.rules:
# BUS="scsi", PROGRAM="/lib/udev/scsi-devfs.sh %k %b %n", NAME="%c{1}", SYMLINK="%c{2} %k"

# Find out where sysfs is mounted. Exit if not available
sysfs=`grep -F sysfs /proc/mounts | awk '{print $2}'`
if [ "$sysfs" = "" ]; then
    echo "sysfs is required"
    exit 1
fi
cd $sysfs/bus/scsi/devices

case "$1" in
  sd*)
    # Extract partition component
    if [ "$3" = "" ]; then
	lpart="disc"
	spart=""
    else
	lpart="part$3"
	spart="p$3"
    fi
    ;;
  sr*)
    lpart="cdrom"
    spart=""
    ;;
  st*)
    # Not supported yet
    exit 1
    ;;
  sg*)
    lpart="generic"
    spart=""
    ;;
  *)
    exit 1
    ;;
esac

# Extract SCSI logical address components
scsi_host=`echo $2 | cut -f 1 -d:`
scsi_bus=`echo $2 | cut -f 2 -d:`
scsi_target=`echo $2 | cut -f 3 -d:`
scsi_lun=`echo $2 | cut -f 4 -d:`

# Generate common and logical names
l_com="bus$scsi_bus/target$scsi_target/lun$scsi_lun/$lpart"
l_log="scsi/host$scsi_host/$l_com"

if [ -d /dev/discs ] ; then
	for x in /dev/discs/disc* ; do
	       if readlink `ls -d $x/* | awk '{print $0; exit;}'` | grep -q "${l_log%${lpart}}" ; then
		       x=`echo $x | cut -f3 -dc` # gives the number in disc0
		       break
	       fi
	       unset x
	done
fi

if [ -z "${x}" ] ; then
	x="`ls /dev/discs/ 2> /dev/null | grep -c .`"
fi

echo $l_log discs/disc${x}/${lpart}
