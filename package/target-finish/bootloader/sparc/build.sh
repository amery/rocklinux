
cd $disksdir

# echo "Cleaning boot directory:"
# rm -rfv boot/*-rock boot/System.map boot/kconfig* boot/initrd*img boot/*.b

echo "Creating silo setup:"
#
echo "Extracting silo boot loader images."
mkdir -p boot
pkg_ver="$( grep " silo " $base/config/$config/packages | cut -f6 -d" " )"
pkg_extraver="$( grep " silo " $base/config/$config/packages | cut -f7 -d" " )"
eval x=$build_rock/pkgs/silo$pkg_suffix
echo $x ver $pkg_ver extraver $pkg_extraver
if [[ "$pkg_suffix" == *gem ]] ; then
	mine -k pkg_tarbz2 $x > $tmpdir/silo.tar.bz2
	x=$tmpdir/silo.tar.bz2
fi
tar -O $taropt $x boot/second.b > boot/second.b
#
echo "Creating silo config file."
cp -v $confdir/sparc/{silo.conf,boot.msg,help1.txt} boot/
#
echo "Copying images to boot directory."
cp -p $ROCKCFG_PKG_1ST_STAGE_INITRD.gz $rootdir/boot/{vmlinuz32,image} boot/ || true
#
cat > $build_rock/isofs_arch.txt <<- EOT
	BOOT	-G $rootdir/boot/isofs.b -B ...
	DISK1	$disksdir/boot/ boot/
EOT
