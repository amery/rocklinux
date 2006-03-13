
echo_header "Creating initrd data:"
rm -rf $disksdir/initrd
mkdir -p $disksdir/initrd/{dev,proc,sys,tmp,scsi,net,bin,etc,lib}
cd $disksdir/initrd; ln -s bin sbin; ln -s . usr

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
cp ${base}/build/${ROCKCFG_ID}/isomd5sum/checkisomd5 bin/
rm -rf ${base}/build/${ROCKCFG_ID}/compile_isomd5sum.sh ${base}/build/${ROCKCFG_ID}/isomd5sum
echo_status "Copying and adjusting linuxrc scipt"
cp ${base}/target/${target}/linuxrc.sh linuxrc
chmod +x linuxrc
sed -i -e "s,^STAGE_2_BIG_IMAGE=\"2nd_stage.tar.gz\"$,STAGE_2_BIG_IMAGE=\"${ROCKCFG_SHORTID}/2nd_stage.tar.gz\"," \
       -e "s,^STAGE_2_SMALL_IMAGE=\"2nd_stage_small.tar.gz\"$,STAGE_2_SMALL_IMAGE=\"${ROCKCFG_SHORTID}/2nd_stage_small.tar.gz\"," \
       linuxrc

echo_status "Copy various helper applications."
for file in ../2nd_stage/bin/{tar,gzip,bash2,bash,sh,mount,umount,ls,cat,uname,rm,ln,mkdir,rmdir,gawk,awk,grep,sleep} \
	    ../2nd_stage/sbin/{ip,hwscan,pivot_root,swapon,swapoff,udevstart} \
	    ../2nd_stage/usr/bin/{wget,find,expand,readlink} \
	    ../2nd_stage/usr/sbin/lspci ; do
	programs="${programs} ${file#../2nd_stage}"
	cp ${file} bin/
done
cp -a $build_root/etc/udev etc/
cp -a $build_root/lib/udev lib/

for x in modprobe.static modprobe.static.old insmod.static insmod.static.old ; do
	if [ -f ../2nd_stage/sbin/${x/.static/} ]; then
		rm -f bin/${x/.static/}
		cp -a ../2nd_stage/sbin/${x/.static/} bin/
	fi
	if [ -f ../2nd_stage/sbin/$x ]; then
		rm -f bin/$x bin/${x/.static/}
		cp -a ../2nd_stage/sbin/$x bin/
		ln -sf $x bin/${x/.static/}
	fi
done

echo_status "Copy scsi and network kernel modules."
for x in ../2nd_stage/lib/modules/*/kernel/drivers/{scsi,net}/*.{ko,o} ; do
	# this test is needed in case there are only .o or only .ko files
	if [ -f $x ]; then
		xx=${x#../2nd_stage/}
		mkdir -p $( dirname $xx ) ; cp $x $xx
		$STRIP --strip-debug $xx # stripping more breaks the object
	fi
done

for x in ../2nd_stage/lib/modules/*/modules.{dep,pcimap,isapnpmap} ; do
	cp $x ${x#../2nd_stage/} || echo "not found: $x" ;
done

for x in lib/modules/*/kernel/drivers/{scsi,net}; do
	[ -d $x ] && ln -s ${x#lib/modules/} lib/modules/
done
rm -f lib/modules/[0-9]*/kernel/drivers/scsi/{st,scsi_debug}.{o,ko}
rm -f lib/modules/[0-9]*/kernel/drivers/net/{dummy,ppp*}.{o,ko}

echo_status "Copying necessary libraries"

libs="/lib/ld-linux.so.2 /usr/lib/libpopt.so.0"
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
		mkdir -p ./${x%/*}
		if [ ! -e ./$x ] ; then
			cp ${base}/build/${ROCKCFG_ID}/$x ./$x
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

ramdisk_size=8192

echo_status "Creating temporary files."
tmpdir=initrd_$$.dir; mkdir -p $disksdir/$tmpdir; cd $disksdir
dd if=/dev/zero of=initrd.img bs=1024 count=$ramdisk_size &> /dev/null
tmpdev="`losetup -f`"
if [ -z "$tmpdev" ] ; then
	for x in /dev/loop* /dev/loop/* ; do
		[ -b "${x}" ] || continue
		losetup ${x} 2>&1 >/dev/null || tmpdev="${x}"
		[ -n "${tmpdev}" ] && break
	done
	if [ -z "${tmpdev}" ] ; then
		echo_error "No free loopback device found!"
		rm -f $tmpfile ; rmdir $tmpdir; exit 1
	fi
fi
echo_status "Using loopback device $tmpdev."
losetup "$tmpdev" initrd.img

echo_status "Writing initrd image file."
mke2fs -m 0 -N 360 -q $tmpdev &> /dev/null
mount -t ext2 $tmpdev $tmpdir
rmdir $tmpdir/lost+found/
cp -a initrd/* $tmpdir
umount $tmpdir

echo_status "Compressing initrd image file."
gzip -9 initrd.img 
mv initrd{.img,}.gz

echo_status "Removing temporary files."
losetup -d $tmpdev
rm -rf $tmpdir
