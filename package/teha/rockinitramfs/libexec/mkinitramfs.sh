#!/bin/sh

# create initramfs image by using gen_cpio_init
# (we do not need root privileges for this!)
#
# see ./build.d/ to see how the content is created!

export PATH=$PATH:/sbin:/bin:/usr/bin:/usr/sbin

k_ver=`uname -r`

usage() {
	cat <<-EOF
	mkinitramfs - create initramfs image by using gen_cpio_init

	mkinitramfs [ -r KERNEL_VERSION ] [ -m MODULES_DIR ] [ -o OUTPUT_FILE ]

	If no options are given the following defaults apply:
		mkinitramfs -r $k_ver -m $mod_origin -o $outfile

	Options:
		-r	Specify kernel version to use for modules dir
		-m	Specify directory where to search for kernel modules
		-o	Specify location of output file

		--root-dir
		--build-dir
		--files-dir

	EOF
}

rootdir=""

while [ ${#} -gt 0 ]
do
	case "$1" in
		-v)	verbose=yes
			;;
		-r)
			k_ver=$2
			shift
			;;
		-m)
			mod_origin=$2
			shift
			;;
		-o)
			outfile=$2
			shift
			;;
		-p)
			scriptopt="$scriptopt ${2%%=*}='${2#*=}'"
			shift
			;;
		--root-dir)
			rootdir="$2"
			shift
			;;
		--build-dir)
			builddir="$2"
			shift
			;;
		--files-dir)
			filesdir="$2"
			shift
			;;
		--add-gen-line)
			additional_gen_lines="$additional_gen_lines;$2"
			shift
			;;
		*)
			usage=1
			;;
	esac
	shift
done

[ -n "${rootdir}" -a "${rootdir:0:1}" != "/" ] && rootdir="`pwd`/$rootdir"

[ -z "$mod_origin" ] && mod_origin=$rootdir/lib/modules/$k_ver
[ -z "$outfile" ] && outfile=$rootdir/boot/initramfs-$k_ver.cpio.gz

if [ "$usage" = "1" ]
then
	usage
	exit
fi

export BASE=$rootdir/lib/rock_initramfs
export LIBEXEC=${BASE}/libexec

[ -z "$builddir" ] && builddir="$BASE/build.d"
[ -z "$filesdir" ] && filesdir="$BASE/files"
[ "${builddir:0:1}" = "/" ] || builddir="$rootdir/$builddir"
[ "${filesdir:0:1}" = "/" ] || filesdir="$rootdir/$filesdir"

[ ${outfile:0:1} = "/" ] || outfile="`pwd`/$outfile"
[ ${mod_origin:0:1} = "/" ] || mod_origin="`pwd`/$mod_origin"


cat << EOF
kernel version: $k_ver
module origin: $mod_origin
output file: $outfile

root dir: $rootdir
build dir: $builddir
files dir: $filesdir
EOF

export rootdir
export builddir
export filesdir
export verbose

export k_ver mod_origin scriptopt

# provide a tmpdir to our helpers
export TMPDIR="/tmp/irfs-`date +%s`.$$"
mkdir -pv $TMPDIR

# compile our list of cpio-content
${LIBEXEC}/build-list.sh > ${TMPDIR}/list
echo "$additional_gen_lines" | tr ';' '\n' >> ${TMPDIR}/list

if [ -n "$verbose" ]
then
	echo "compiled list:"
	echo "======================="
	cat ${TMPDIR}/list
	echo "======================="
fi

# create and compress cpio archive
${LIBEXEC}/${cross_compile}gen_init_cpio ${TMPDIR}/list | gzip -9 > $outfile

if [ -n "$verbose" ]
then
	echo "contents of TMPDIR=$TMPDIR:"
	echo "======================="
	find $TMPDIR
	echo "======================="
fi
# remove the tmpdir
rm -rf $TMPDIR

# can be extracted with:
# gzip -dc ../irfs.cpio.gz | ( rm -rf ./root ; mkdir root ; cd root ; cpio -i -d -H newc --no-absolute-filenames )