#!/bin/sh

kernel=`uname -r`
tmpdir=`mktemp -d`

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
	while read a b ; do
		b="`find /lib/modules/$kernel -name "$b.o" -o -name "$b.ko"`"
#b=${b//`uname -r`/$kernel} # substitute autodetected value by correct value
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

targetdir=$tmpdir
programs="/bin/bash /bin/bash2 /bin/sh /bin/ls /sbin/pivot_root /sbin/insmod /sbin/insmod.old /bin/mount /bin/umount /usr/bin/chroot /etc/fstab /bin/mkdir"

libs=""
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

# This works, but only for initrd images < 4 MB
itmp=`mktemp`
#/boot/initrdnew-${kernel}.img.tmp \
dd if=/dev/zero of=${itmp} count=8192 bs=1024 > /dev/null 2>&1
mke2fs -m 0 -N 5120 -F ${itmp} > /dev/null 2>&1
mntpoint="`mktemp -d`"
mount -o loop ${itmp} $mntpoint
rmdir $mntpoint/lost+found/
cp -a $tmpdir/* $mntpoint/
umount -d $mntpoint
rmdir $mntpoint

gzip -9 < ${itmp} > /boot/initrdnew-${kernel}.img
rm -f ${itmp}

rm -rf $tmpdir
echo "Done."

