
echo_header "Creating initrd data:"
rm -rf $disksdir/initrd
mkdir -p $disksdir/initrd/{dev,proc,tmp,lib,bin,mnt_boot,mnt_root}
cd $disksdir/initrd
ln -s bin sbin
ln -s . usr

echo_status "Copying linuxrc binary."
cp -v $rootdir/sbin/init sbin/

echo_status "Copy libc stuff."
cp -a $rootdir/lib/ld-*.so \
	$rootdir/lib/ld-linux* \
	$rootdir/lib/libc-* \
	$rootdir/lib/libc.* \
	$rootdir/lib/libc.* \
	$rootdir/lib/libresolv* \
	lib/

if [[ $rockver != 2.0* ]] ; then
	echo_status "Copy some additional libs for tar."
	cp -a $rootdir/lib/lib{pthread,rt}{.,-}* \
	lib/
fi

echo_status "Copy various helper applications."
cp $rootdir/bin/{tar,gzip,bzip2} bin/
cp $rootdir/sbin/{insmod,ip} bin/
cp $rootdir/usr/bin/wget bin/

#
if [ "$ROCKCFG_RESCUE_INITRD_USEKISS" = 1 ]; then
	echo_status "Adding kiss shell for expert use of the initrd image."
	cp $rootdir/bin/kiss bin/
fi
cd ..

echo_header "Creating initrd filesystem image: "

ramdisk_size=8192
[ $arch = x86 ] && ramdisk_size=4096

echo_status "Creating temporary files."
tmpdir=initrd_$$.dir
mkdir -p $disksdir/$tmpdir
cd $disksdir

dd if=/dev/zero of=initrd.img bs=1024 count=$ramdisk_size &> /dev/null
tmpdev=""
for x in /dev/loop/* ; do
        if /sbin/losetup $x initrd.img 2> /dev/null ; then
                tmpdev=$x ; break
        fi
done
if [ -z "$tmpdev" ] ; then
        echo_error "No free loopback device found!"
        rm -f $tmpfile ; rmdir $tmpdir; exit 1
fi
echo_status "Using loopback device $tmpdev."

echo_status "Writing initrd image file."
/sbin/mke2fs -m 0 -N 180 -q $tmpdev &> /dev/null
mount -t ext2 $tmpdev $tmpdir
rmdir $tmpdir/lost+found/
cp -a initrd/* $tmpdir
umount $tmpdir

echo_status "Removing temporary files."
/sbin/losetup -d $tmpdev
rm -rf $tmpdir

