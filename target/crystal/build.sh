
# This is the shortest possible target build.sh script. Some targets will
# add code after calling pkgloop() or modify pkgloop's behavior by defining
# a new pkgloop_action() function.
#
pkgloop

echo_header "Finishing build."

echo_status "Selecting bin packages ..."
rm -rf build/${ROCKCFG_ID}/ROCK/pkgs_sel
mkdir -p build/${ROCKCFG_ID}/ROCK/pkgs_sel
ln build/${ROCKCFG_ID}/ROCK/pkgs/* build/${ROCKCFG_ID}/ROCK/pkgs_sel/

# :doc packages are nice but in most cases never used
rm -f build/${ROCKCFG_ID}/ROCK/pkgs_sel/*:doc{-*,}.gem

# remove packages which haven't been built in stages 0-8
if [ "$ROCKCFG_TARGET_CRYSTAL_BUILDADDONS" = 1 ]; then
	for gemfile in build/${ROCKCFG_ID}/ROCK/pkgs_sel/*.gem; do
		if ! mine -k descs $gemfile | grep '^\[P\]' | cut -f3 -d' ' | grep -q '[0-8]'; then
			rm -f $gemfile
		fi
	done
fi

echo_status "Creating package database ..."
admdir="build/${ROCKCFG_ID}/var/adm"
create_package_db $admdir build/${ROCKCFG_ID}/ROCK/pkgs_sel \
                  build/${ROCKCFG_ID}/ROCK/pkgs_sel/packages.db

echo_status "Creating isofs.txt file .."
cat << EOT > build/${ROCKCFG_ID}/ROCK/isofs.txt
DISK1	$admdir/cache/					${ROCKCFG_SHORTID}/info/cache/
DISK1	$admdir/cksums/					${ROCKCFG_SHORTID}/info/cksums/
DISK1	$admdir/dependencies/				${ROCKCFG_SHORTID}/info/dependencies/
DISK1	$admdir/descs/					${ROCKCFG_SHORTID}/info/descs/
DISK1	$admdir/flists/					${ROCKCFG_SHORTID}/info/flists/
DISK1	$admdir/md5sums/				${ROCKCFG_SHORTID}/info/md5sums/
DISK1	$admdir/packages/				${ROCKCFG_SHORTID}/info/packages/
EVERY	build/${ROCKCFG_ID}/ROCK/pkgs_sel/packages.db	${ROCKCFG_SHORTID}/pkgs/packages.db
SPLIT	build/${ROCKCFG_ID}/ROCK/pkgs_sel/		${ROCKCFG_SHORTID}/pkgs/
EOT

