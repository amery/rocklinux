
use_isolinux=1
syslinux_ver="`sed -n 's,.*syslinux-\(.*\).tar.*,\1,p' \
               $base/target/bootdisk/download.txt`"
use_mdlbl=1
mdlbl_ver="`sed -n 's,.*mdlbl-\(.*\).tar.*,\1,p' \
            $base/target/bootdisk/download.txt`"

cd $disksdir

echo "Creating lilo config and cleaning boot directory:"
cp $confdir/x86/lilo-* boot/
rm -rfv boot/*-rock boot/grub boot/System.map boot/kconfig boot/*.24**

echo "Creating floppy disk images:"
cp $confdir/x86/makeimages.sh .
chmod +x makeimages.sh

if [ $use_mdlbl -eq 1 ]
then
	tar $taropt $base/download/mirror/m/mdlbl-$mdlbl_ver.tar.bz2
	cd mdlbl-$mdlbl_ver
	cp ../boot/vmlinuz .; cp ../initrd.gz initrd; ./makedisks.sh
	for x in disk*.img; do mv $x ../floppy${x#disk}; done; cd ..
	du -sh floppy*.img | while read x; do echo $x; done
else
	tmpfile=`mktemp -p $PWD`
	if sh ./makeimages.sh &> $tmpfile; then
		cat $tmpfile | while read x; do echo "$x"; done
	else
		cat $tmpfile | while read x; do echo "$x"; done
	fi
	rm -f $tmpfile
	cat > $xroot/ROCK/isofs_arch.txt <<- EOT
		BOOT	-b ${ROCKCFG_SHORTID}/boot_288.img -c ${ROCKCFG_SHORTID}/boot.catalog
	EOT
fi

if [ $use_isolinux -eq 1 ]
then
	echo "Creating isolinux setup:"
	#
	echo "Extracting isolinux boot loader."
	mkdir -p isolinux
	tar -O $taropt $base/download/mirror/s/syslinux-$syslinux_ver.tar.bz2 \
	    syslinux-$syslinux_ver/isolinux.bin > isolinux/isolinux.bin
	#
	echo "Creating isolinux config file."
	cp $confdir/x86/isolinux.cfg isolinux/
	cp $confdir/x86/help?.txt isolinux/
	#
	echo "Copy images to isolinux directory."
	[ -e boot/memtest86.bin ] && cp boot/memtest86.bin isolinux/memtest86 || true
	cp initrd.gz boot/vmlinuz isolinux/
	#
	cat > $xroot/ROCK/isofs_arch.txt <<- EOT
		BOOT	-b isolinux/isolinux.bin -c isolinux/boot.catalog
		BOOTx	-no-emul-boot -boot-load-size 4 -boot-info-table
		DISK1	build/${ROCKCFG_ID}/ROCK/$target/isolinux/ isolinux/
	EOT
fi

