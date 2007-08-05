
cd $disksdir

echo "Cleaning boot directory:"
rm -rfv boot/*-rock boot/System.map boot/kconfig* boot/initrd*img boot/*.b

echo "Creating silo setup:"
#
echo "Extracting silo boot loader images."
mkdir -p boot
tar $taropt $base/build/${ROCKCFG_ID}/ROCK/pkgs/silo.tar.bz2 \
    boot/second.b -O > boot/second.b
#
echo "Creating silo config file."
cp -v $confdir/sparc/{silo.conf,boot.msg,help1.txt} \
  boot
#
echo "Moving image (initrd) to boot directory."
mv -v initrd.gz boot/
#
buildroot="build/${ROCKCFG_ID}"
datadir="build/${ROCKCFG_ID}/ROCK/$target"
cat > $xroot/ROCK/isofs_arch.txt <<- EOT
	BOOT	-G $buildroot/boot/isofs.b -B ...
	DISK1	$datadir/boot/ boot/
EOT

