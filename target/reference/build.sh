
build_result="$build_rock/result"

pkgloop_action() {

	# Rebuild command line without '$cmd_maketar'
	#
        cmd_buildpkg="./scripts/Build-Pkg -$stagelevel -cfg $config"
        cmd_buildpkg="$cmd_buildpkg $cmd_root $cmd_prefix $pkg_basename=$pkg_name"

	# Build package
	#
	$cmd_buildpkg ; rc=$?

	# Copy *.cache file
	#
	if [ -f "$build_root/var/adm/cache/$pkg_name" ] ; then
		dir="$build_result/package/$pkg_tree/$pkg_basename" ; mkdir -p $dir
		cp $build_root/var/adm/cache/$pkg_name $dir/$pkg_name.cache
	fi

	return $rc
}

pkgloop

echo_header "Finishing build."

echo_status "Copying error logs and rock-debug data."
mkdir -p $build_result/{errors,rock-debug,dep-debug}
cp -r $build_root/var/adm/rock-debug/. $build_result/rock-debug/
cp -r $build_root/var/adm/dep-debug/. $build_result/dep-debug/
cp $build_root/var/adm/logs/*.err $build_result/errors/ 2> /dev/null

echo_status "Creating package database ..."
admdir="build/${ROCKCFG_ID}/var/adm"
create_package_db $admdir build/${ROCKCFG_ID}/ROCK/pkgs

echo_status "Creating isofs.txt file .."
cat << EOT > build/${ROCKCFG_ID}/ROCK/isofs.txt
DISK1	$admdir/cache/					${ROCKCFG_SHORTID}/info/cache/
DISK1	$admdir/cksums/					${ROCKCFG_SHORTID}/info/cksums/
DISK1	$admdir/dependencies/				${ROCKCFG_SHORTID}/info/dependencies/
DISK1	$admdir/descs/					${ROCKCFG_SHORTID}/info/descs/
DISK1	$admdir/flists/					${ROCKCFG_SHORTID}/info/flists/
DISK1	$admdir/md5sums/				${ROCKCFG_SHORTID}/info/md5sums/
DISK1	$admdir/packages/				${ROCKCFG_SHORTID}/info/packages/
EVERY	build/${ROCKCFG_ID}/ROCK/pkgs/packages.db	${ROCKCFG_SHORTID}/pkgs/packages.db
SPLIT	build/${ROCKCFG_ID}/ROCK/pkgs/			${ROCKCFG_SHORTID}/pkgs/
EOT

echo_header "Reference build finished."

cp misc/tools-source/copy-cache.sh build/${ROCKCFG_ID}/ROCK/result/copy-cache.sh
chmod +x build/${ROCKCFG_ID}/ROCK/result/copy-cache.sh

echo_status "Results are stored in the directory"
echo_status "build/$ROCKCFG_ID/ROCK/result/."

