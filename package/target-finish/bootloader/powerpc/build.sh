
use_yaboot=1

cd $disksdir

echo "Creating cleaning boot directory:"
rm -rfv boot/*-rock boot/System.map boot/kconfig*

if [ $use_yaboot -eq 1 ]
then
	echo "Creating yaboot setup:"
	#
	echo "Extracting yaboot boot loader images."
	mkdir -p boot etc
	tar -O $taropt $base/build/${ROCKCFG_ID}/ROCK/pkgs/yaboot.tar.bz2 \
	    usr/lib/yaboot/yaboot > boot/yaboot
	tar -O $taropt $base/build/${ROCKCFG_ID}/ROCK/pkgs/yaboot.tar.bz2 \
            usr/lib/yaboot/yaboot.rs6k > boot/yaboot.rs6k
	cp boot/yaboot.rs6k install.bin
	#
	echo "Creating yaboot config files."
	cp -v $confdir/powerpc/{boot.msg,ofboot.b} \
	  boot
	(
		echo "device=cdrom:" 
		cat $confdir/powerpc/yaboot.conf
	) > etc/yaboot.conf
	(
		echo "device=cd:"
		cat $confdir/powerpc/yaboot.conf
	) > boot/yaboot.conf
	#
	echo "Moving image (initrd) to boot directory."
	mv -v initrd.gz boot/
	#
	echo "Copy more config files."
	cp -v $confdir/powerpc/mapping .
	#
	datadir="build/${ROCKCFG_ID}/ROCK/target-finish"
	cat > $xroot/ROCK/isofs_arch.txt <<- EOT
		BOOT	-hfs -part -map $datadir/mapping -hfs-volid "ROCK_Linux_CD"
		BOOTx	-hfs-bless boot -sysid PPC -l -L -r -T -chrp-boot
		BOOTx   --prep-boot install.bin
		DISK1	$datadir/boot/ boot/
		DISK1	$datadir/etc/ etc/
		DISK1	$datadir/install.bin install.bin
	EOT
#		SCRIPT  sh $confdir/powerpc/bless-rs6k.sh $disksdir
fi

