#
set -e
#
echo_header "Creating 2nd stage filesystem:"
mkdir -p $disksdir/2nd_stage
cd $disksdir/2nd_stage
mkdir -p mnt/source mnt/target ramdisk
#
echo_status "Extracting the packages archives."
for x in $( ls ../../pkgs/*.tar.bz2 | \
		 grep -v ':doc.tar.bz2' )
do
	echo_status "\`- Extracting ${x##*/} ..."
	tar --use-compress-program=bzip2 --force-local -xpf $x
done
#
echo_status "Saving boot/* - we do not need this on the 2nd stage ..."
rm -rf ../boot ; mkdir ../boot
mv boot/* ../boot/
#
echo_status "Remove the stuff we do not need ..."
rm -rf usr/src
#
# TODO finish-package!!
echo_status "Running ldconfig to create links ..."
ldconfig -r .
#
echo_status "replacing some vital files for live useage ..."
cp -f $base/target/$target/fixedfiles/inittab etc/inittab
cp -f $base/target/$target/fixedfiles/login-shell sbin/login-shell
# this got drop once, so we ensure it's +xed.
chmod 0755 sbin/login-shell
cp -f $base/target/$target/fixedfiles/system etc/rc.d/init.d/system
cp -f $base/target/$target/fixedfiles/xorg.conf etc/X11/xorg.conf
#
echo_status "Creating 2nd_stage.img.z image... (this takes some time)... "
cd .. ; mksquashfs 2nd_stage 2nd_stage.img.z -noappend > /dev/null 2>&1
