
echo_header "Creating initrd data:"
rm -rf $disksdir/initrd
mkdir -p $disksdir/initrd/{dev,sys,proc,mnt/{cdrom,floppy,stick,}}
mkdir -p $disksdir/initrd/mnt/{cowfs_ro/{bin,lib},cowfs_rw}
cd $disksdir/initrd; ln -s mnt/cowfs_ro/bin mnt/cowfs_ro/sbin; 
#
echo_status "Creating read-only symlinks..."
for d in etc home bin sbin opt usr tmp var lib ; do
	ln -s /mnt/cowfs_rw/$d $d
	ln -s /mnt/cowfs_ro/$d mnt/cowfs_rw/$d
done
#
if [ -x ../../../usr/bin/diet ] ; then
	export DIETHOME="../../../usr/dietlibc"
	LXRCCC="../../../usr/bin/diet $CC";
elif [ -x /usr/bin/diet ] ; then
	echo_status "using host's diet - did the target's dietlibc build fail?"
	LXRCCC="/usr/bin/diet $CC";
else
	echo_status "diet not found - using glibc -static - initrd may be too big..."
	LXRCCC="$CC -static"
fi
echo_status "Create linuxrc binary."
$LXRCCC $base/target/$target/linuxrc.c -Wall \
	-DSTAGE_2_IMAGE="\"${ROCKCFG_SHORTID}/2nd_stage.img.z\"" \
	-o linuxrc
#
echo_status "Copy various helper applications."
cp ../2nd_stage/bin/{tar,gzip} mnt/cowfs_ro/bin/
cp ../2nd_stage/sbin/hwscan mnt/cowfs_ro/bin/
cp ../2nd_stage/usr/bin/gawk mnt/cowfs_ro/bin/
for x in modprobe.static modprobe.static.old \
         insmod.static insmod.static.old
do
	if [ -f ../2nd_stage/sbin/${x/.static/} ]; then
		rm -f mnt/cowfs_ro/bin/${x/.static/}
		cp -a ../2nd_stage/sbin/${x/.static/} mnt/cowfs_ro/bin/
	fi
	if [ -f ../2nd_stage/sbin/$x ]; then
		rm -f mnt/cowfs_ro/bin/$x mnt/cowfs_ro/bin/${x/.static/}
		cp -a ../2nd_stage/sbin/$x mnt/cowfs_ro/bin/
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
#
echo_status "Adding kiss shell for expert use of the initrd image."
cp $build_root/bin/kiss mnt/cowfs_ro/bin/
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
mke2fs -m 0 -N 180 -q $tmpdev &> /dev/null
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
