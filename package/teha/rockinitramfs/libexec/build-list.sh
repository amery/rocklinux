#!/bin/sh
# create the list for cpio-entries to be used by gen_cpio_init
# shall be called by mkinitramfs.sh only.
# sources each file in ./build.d/


#!/bin/sh
#
# find dynamic (share library) dependencies for a binary
# courtesy of rockinitrd package.
#

libdirs=""
for N in ${rootdir}/lib `sed -e"s,^,${rootdir}," ${rootdir}/etc/ld.so.conf | tr '\n' ' '` ; do
	[ -d "$N" ] && libdirs="$libdirs $N"
done
needed_libs() {
	local x y z library libqueue liblist

	libqueue="$( mktemp -t libqueue-XXXXXX )"
	liblist="$( mktemp -d -t liblist-XXXXXX )"

	# initialize the queue
	for x ; do
		echo "$x"
	done > "$libqueue"

	# get the required libraries of each file
	while read y ; do
		${cross_compile}readelf -d "${y}" 2>/dev/null | grep "(NEEDED)" |
		sed -e "s,.*Shared library: \[\(.*\)\],\1," |
		while read library ; do
			[ -e "$liblist/$library" ] && continue

			# use the first library with this name
			find ${libdirs} -maxdepth 1 -name "${library}" 2>/dev/null |
			head -n1 |
			while read z ; do
				# put the libraries found into the queue, because they might
				# require other libraries themselves
				echo "$z" >> "$libqueue"
				echo "$z"
			done

			# list this library as processed
			touch "$liblist/$library"
		done
	done < "$libqueue"
	rm -f "$libqueue" ; rm -rf "$liblist"
}

# add a file ($1) to the contents-list of initramfs
# optionally you can give a different destination filename
# in $2
# the output is a gen_init_cpio compatible list including all 
# dynamic dependencies and the file itself.
add_with_deps() {
	srcname=$1 ; shift
	dstname=$srcname
	[ -n "$1" ] && dstname=$1

	echo "file $dstname $srcname 755 0 0"
	needed_libs $srcname | while read lib
	do
		echo "file /lib/`basename $lib` $lib 755 0 0"
	done
}

mkdir -pv $TMPDIR/targetdir

# now go through the build.d directory
for x in $builddir/[0-9][0-9]*
do
	echo
	echo "sourcing $x ($scriptopt)" >&2
	# use the same environment for each script
	( cd $TMPDIR/targetdir ; eval $scriptopt ; . $x )
done | sort -u
