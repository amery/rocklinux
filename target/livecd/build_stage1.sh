
echo_header "Creating initrd data:"
rm -rf $disksdir/initrd
mkdir -p $disksdir/initrd/{dev,sys,proc,mnt/{cdrom,floppy,stick,}}
mkdir -p $disksdir/initrd/mnt/{cowfs_ro/{etc,home,bin,sbin,opt,usr/{bin,sbin},tmp,var,lib},cowfs_rw}
cd $disksdir/initrd
#
echo_status "Creating read-only symlinks..."
for d in etc home bin sbin opt usr tmp var lib ; do
	ln -s /mnt/cowfs_rw/$d $d
	ln -s /mnt/cowfs_ro/$d mnt/cowfs_rw/$d
done
#
if [ -L $disksdir/2nd_stage/lib64 ] ; then
	ln -s /mnt/cowfs_rw/lib64 lib64
	ln -s /mnt/cowfs_ro/lib64 mnt/cowfs_rw/lib64
fi

echo_status "Creating some device nodes"
mknod dev/ram0  b 1 0
mknod dev/null  c 1 3
mknod dev/zero  c 1 5
mknod dev/tty   c 5 0
mknod dev/console c 5 1

echo_status "Create checkisomd5 binary"
cp -r ${base}/misc/isomd5sum ${base}/build/${ROCKCFG_ID}/
cat >${base}/build/${ROCKCFG_ID}/compile_isomd5sum.sh <<EOF
#!/bin/bash
cd /isomd5sum
make clean
make CC=gcc
EOF
chmod +x ${base}/build/${ROCKCFG_ID}/compile_isomd5sum.sh
chroot ${base}/build/${ROCKCFG_ID}/ /compile_isomd5sum.sh
cp ${base}/build/${ROCKCFG_ID}/isomd5sum/checkisomd5 mnt/cowfs_ro/bin/
rm -rf ${base}/build/${ROCKCFG_ID}/compile_isomd5sum.sh ${base}/build/${ROCKCFG_ID}/isomd5sum

echo_status "Copying and adjusting linuxrc scipt"
cp ${base}/target/${target}/linuxrc.sh linuxrc
chmod +x linuxrc
#sed -i -e "s,^STAGE_2_BIG_IMAGE=\"2nd_stage.tar.gz\"$,STAGE_2_BIG_IMAGE=\"${ROCKCFG_SHORTID}/2nd_stage.tar.gz\"," \
#       -e "s,^STAGE_2_SMALL_IMAGE=\"2nd_stage_small.tar.gz\"$,STAGE_2_SMALL_IMAGE=\"${ROCKCFG_SHORTID}/2nd_stage_small.tar.gz\"," \
sed -i -e "s,\(^STAGE_2_BIG_IMAGE=\"\)\(2nd_stage.img.z\"$\),\1${ROCKCFG_SHORTID}/\2," \
       linuxrc

#
echo_status "Copy various helper applications."
cp ../2nd_stage/bin/{tar,gzip} mnt/cowfs_ro/bin/
cp ../2nd_stage/sbin/hwscan mnt/cowfs_ro/sbin/
cp ../2nd_stage/usr/bin/gawk mnt/cowfs_ro/bin/

for file in ../2nd_stage/bin/{tar,gzip,bash2,bash,sh,mount,umount,ls,cat,uname,rm,ln,mkdir,rmdir,gawk,awk,grep,sleep,dmesg} \
	    ../2nd_stage/sbin/{ip,hwscan,pivot_root,swapon,swapoff,udev*,losetup} \
	    ../2nd_stage/usr/bin/{wget,find,expand,readlink} \
	    ../2nd_stage/usr/sbin/lspci ; do
	programs="${programs} ${file#../2nd_stage}"
	cp ${file} mnt/cowfs_ro/${file#../2nd_stage/}
done
cp -a $build_root/etc/udev mnt/cowfs_ro/etc/

for x in modprobe.static modprobe.static.old \
         insmod.static insmod.static.old
do
	if [ -f ../2nd_stage/sbin/${x/.static/} ]; then
		rm -f mnt/cowfs_ro/bin/${x/.static/}
		cp -a ../2nd_stage/sbin/${x/.static/} mnt/cowfs_ro/sbin/
	fi
	if [ -f ../2nd_stage/sbin/$x ]; then
		rm -f mnt/cowfs_ro/bin/$x mnt/cowfs_ro/bin/${x/.static/}
		cp -a ../2nd_stage/sbin/$x mnt/cowfs_ro/sbin/
		ln -sf $x mnt/cowfs_ro/bin/${x/.static/}
	fi
done
#
echo_status "Copy kernel modules."
for x in ../2nd_stage/lib/modules/*/kernel/drivers/{scsi,cdrom,ide,ide/pci,ide/legacy}/*.{ko,o} ; do
	# this test is needed in case there are only .o or only .ko files
	if [ -f $x ]; then
		xx=mnt/cowfs_ro/${x#../2nd_stage/}
		mkdir -p $( dirname $xx ) ; cp $x $xx
		strip --strip-debug $xx 
	fi
done
#
for x in ../2nd_stage/lib/modules/*/modules.{dep,pcimap,isapnpmap} ; do
	cp $x mnt/cowfs_ro/${x#../2nd_stage/} || echo "not found: $x" ;
done
#
rm -f mnt/cowfs_ro/lib/modules/[0-9]*/kernel/drivers/net/{dummy,ppp*}.{o,ko}

echo_status "Copying necessary libraries"

libs="/lib/ld-linux.so.2 /lib/libdl.so.2 /lib/libc.so.6 /lib/librt.so.1 /lib/libpthread.so.0 /usr/lib/libpopt.so.0"
# libpopt from checkisomd5 which is not in build/*
for x in ${programs} ; do
	[ -e ./$x ] || continue
	file $x | grep -q ELF || continue
	libs="$libs `chroot ${base}/build/${ROCKCFG_ID} ldd $x 2>/dev/null | grep -v 'not a dynamic executable' | sed -e 's,^[\t ]*,,g' | cut -f 3 -d' '`"
done

while [ -n "$libs" ] ; do
	oldlibs=$libs
	libs=""
	for x in $oldlibs ; do
		mkdir -p mnt/cowfs_ro/${x%/*}
		if [ ! -e ./$x ] ; then
			cp ${base}/build/${ROCKCFG_ID}/$x mnt/cowfs_ro/$x
			echo_status "- ${x##*/}"
		fi
		file $x | grep -q ELF || continue
		for y in `chroot ${base}/build/${ROCKCFG_ID} ldd $x 2>/dev/null | grep -v 'not a dynamic executable' | sed -e 's,^[\t ]*,,g' | cut -f 3 -d' '` ; do
			[ ! -e "./$y" ] && libs="$libs $y"
		done
	done
done

echo_status "Creating links for identical files."
while read ck fn
do
	if [ "$oldck" = "$ck" ] ; then
		echo_status "\`- Found $fn -> $oldfn."
		rm $fn ; ln -s ${oldfn#.} $fn
	else
		oldck=$ck ; oldfn=$fn
	fi
done < <( find -type f | xargs md5sum | sort )

cd ..

echo_header "Creating initrd filesystem image: "

ramdisk_size=8139

echo_status "Creating temporary files."
tmpdir=initrd_$$.dir; mkdir -p $disksdir/$tmpdir; cd $disksdir
dd if=/dev/zero of=initrd.img bs=1024 count=$ramdisk_size &> /dev/null
tmpdev=""
for x in /dev/loop/* ; do
        if losetup $x initrd.img 2> /dev/null ; then
                tmpdev=$x ; break
        fi
done
if [ -z "$tmpdev" ] ; then
        echo_error "No free loopback device found!"
        rm -f $tmpfile ; rmdir $tmpdir; exit 1
fi
echo_status "Using loopback device $tmpdev."
#
echo_status "Writing initrd image file."
mke2fs -m 0 -N 360 -q $tmpdev &> /dev/null
mount -t ext2 $tmpdev $tmpdir
rmdir $tmpdir/lost+found/
cp -a initrd/* $tmpdir
umount $tmpdir
#
echo_status "Compressing initrd image file."
gzip -9 initrd.img 
mv initrd{.img,}.gz
#
echo_status "Removing temporary files."
losetup -d $tmpdev
rm -rf $tmpdir
