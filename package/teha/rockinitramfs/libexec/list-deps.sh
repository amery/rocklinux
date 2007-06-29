#!/bin/sh
#
# find dynamic (share library) dependencies for a binary
# courtesy of rockinitrd package.
#
export rootdir=""

export libdirs="${rootdir}/lib ${rootdir}/usr/lib"

for x in $*
do
	readelf -d $x 2>/dev/null | grep "(NEEDED)" |
		sed -e"s,.*Shared library: \[\(.*\)\],\1," |
		while read library ; do
			find $libdirs -maxdepth 1 -name "$library" |
			sed -e "s,^$rootdir,,g"
		done
done
