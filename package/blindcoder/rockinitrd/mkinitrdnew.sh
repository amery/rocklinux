#!/bin/bash

kernel=`uname -r`
tmpdir=`mktemp -d`
modprobeopt=`echo $kernel | sed '/2.4/ { s,.*,-n,; q; }; s,.*,--show-depends,'`

if [ -n "$1" ]; then
	if [ -d "/lib/modules/$1" ]; then
		kernel="$1"
	else
		echo "Can't open /lib/modules/$1: No such directory."
		echo "Usage: $0 [ kernel-version ]"
		exit 1
	fi
fi

echo "Creating /boot/initrdnew-${kernel}.img ..."
mkdir -p $tmpdir/etc/conf
grep '^modprobe ' /etc/conf/kernel | grep -v 'no-initrd' | \
	sed 's,[ 	]#.*,,' | \
	while read a b ; do $a $modprobeopt -v $b 2> /dev/null; done |
	while read a b c; do
		[[ "$b" = *.ko ]] && b=${b/.ko/};
		b="`find /lib/modules/$kernel -wholename "$b.o" -o -wholename "$b.ko"`"
		echo "Adding $b."
		mkdir -p $tmpdir/${b%/*}
		cp $b $tmpdir/$b
		echo "/sbin/insmod $b $c" >> $tmpdir/etc/conf/kernel
	done
mkdir -p $tmpdir/dev $tmpdir/root $tmpdir/tmp $tmpdir/proc $tmpdir/sys
mknod $tmpdir/dev/ram0	b 1 0
mknod $tmpdir/dev/null	c 1 3
mknod $tmpdir/dev/zero	c 1 5
mknod $tmpdir/dev/tty	c 5 0
mknod $tmpdir/dev/console c 5 1
# this copies a set of programs and the necessary libraries into a
# chroot environment

echo -n "Checking necessary fsck programs ... "
while read dev a mnt b fs c ; do
	[ -e "/sbin/fsck.${fs}" ] && echo "/sbin/fsck.${fs} /sbin/fsck.${fs}"
done < <( mount ) | sort | uniq >/etc/conf/initrd/initrd_fsck
echo "/sbin/fsck /sbin/fsck" >>/etc/conf/initrd/initrd_fsck
echo "done"

targetdir=$tmpdir
programs="/bin/bash /bin/bash2 /bin/sh /bin/ls /sbin/pivot_root /sbin/insmod /sbin/insmod.old /bin/mount /bin/umount /usr/bin/chroot /etc/fstab /bin/mkdir"

libs="/lib/ld-linux.so.2"
for x in $programs ; do
	[ -e $x ] || continue
	mkdir -p $targetdir/${x%/*}
	cp -a $x $targetdir/$x
	file $x | grep -q ELF || continue
	libs="$libs `ldd $x 2>/dev/null | grep -v 'not a dynamic executable' | sed -e 's,^[\t ]*,,g' | cut -f 3 -d' '`"
done

for x in /etc/conf/initrd/initrd_* ; do
	[ -f $x ] || continue
	while read file target ; do
		if [ -d $file ] ; then
			find $file -type f | while read f ; do
				tfile=${targetdir}/${target}/${f#$file}
				[ -e $tfile ] && continue
				mkdir -p ${tfile%/*}
				cp $f $tfile
				libs="$libs `ldd $f 2>/dev/null | grep -v 'not a dynamic executable' | sed -e 's,^[\t ]*,,g' | cut -f 3 -d' '`"
			done
		fi
		[ -f $file ] || continue
		mkdir -p $targetdir/${target%/*}
		cp $file $targetdir/$target
		file $file | grep -q ELF || continue
		libs="$libs `ldd $file 2>/dev/null | grep -v 'not a dynamic executable' | sed -e 's,^[\t ]*,,g' | cut -f 3 -d' '`"
	done < $x
done

while [ -n "$libs" ] ; do
	oldlibs=$libs
	libs=""
	for x in $oldlibs ; do
		mkdir -p $targetdir/${x%/*}
		cp $x $targetdir/$x
		file $x | grep -q ELF || continue
		for y in `ldd $x 2>/dev/null | grep -v 'not a dynamic executable' | sed -e 's,^[\t ]*,,g' | cut -f 3 -d' '` ; do
			[ ! -e "$targetdir/$y" ] && libs="$libs $y"
		done
	done
done

itmp=`mktemp`
mkfs.cramfs $tmpdir ${itmp}
gzip -9 < ${itmp} > /boot/initrdnew-${kernel}.img
rm -f ${itmp}

rm -rf $tmpdir
echo "Done."

