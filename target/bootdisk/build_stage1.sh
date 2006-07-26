#!/bin/bash

echo_header "Creating initrd data:"
rm -rf $disksdir/initrd
mkdir -p $disksdir/initrd/{dev,proc,sys,tmp,scsi,net,bin,etc,lib}
cd $disksdir/initrd; ln -s bin sbin; ln -s . usr

rock_targetdir="$base/target/$target/"
rock_target="$target"

rootdir="$disksdir/2nd_stage"
targetdir="$disksdir/initrd"
cross_compile=""
if [ "$ROCKCFG_CROSSBUILD" = "1" ] ; then
	cross_compile="`find ${base}/ROCK/tools.cross/ -name "*-readelf"`"
	cross_compile="${cross_compile##*/}"
	cross_compile="${cross_compile%%readelf}"
fi
initrdfs="ext2fs"
block_size=""
ramdisk_size=12288

case ${initrdfs} in
	ext2fs|ext3fs|cramfs) 
		initrd_img="${disksdir}/initrd.img"
		;;
	ramfs)
		initrd_img="${disksdir}/initrd.cpio"
		;;
esac

echo_status "Creating some device nodes"
mknod ${targetdir}/dev/ram0	b 1 0
mknod ${targetdir}/dev/null	c 1 3
mknod ${targetdir}/dev/zero	c 1 5
mknod ${targetdir}/dev/tty	c 5 0
mknod ${targetdir}/dev/console	c 5 1

# this copies a set of programs and the necessary libraries into a
# chroot environment

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
cp ${base}/target/${target}/linuxrc.sh sbin/init
chmod +x sbin/init
sed -i -e "s,^STAGE_2_BIG_IMAGE=\"2nd_stage.tar.gz\"$,STAGE_2_BIG_IMAGE=\"${ROCKCFG_SHORTID}/2nd_stage.tar.gz\"," \
       -e "s,^STAGE_2_SMALL_IMAGE=\"2nd_stage_small.tar.gz\"$,STAGE_2_SMALL_IMAGE=\"${ROCKCFG_SHORTID}/2nd_stage_small.tar.gz\"," \
       sbin/init

libdirs="${rootdir}/lib `sed -e"s,^\(.*\),${rootdir}\1," ${rootdir}/etc/ld.so.conf | tr '\n' ' '`"

needed_libs() {
	local x="${1}" library

	${cross_compile}readelf -d ${x} 2>/dev/null | grep "(NEEDED)" |
		sed -e"s,.*Shared library: \[\(.*\)\],\1," |
		while read library ; do
			find ${libdirs} -name "${library}" 2>/dev/null |
			sed -e "s,^${rootdir},,g" | tr '\n' ' '
		done
}

libs="${libs} `needed_libs bin/checkisomd5`"

echo_status "Copying other files ... "
for x in ${rock_targetdir}/initrd/initrd_* ; do
	[ -f ${x} ] || continue
	while read file target ; do
		file="${rootdir}/${file}"
		[ -e ${file} ] || continue

		while read f ; do
			tfile=${targetdir}/${target}${f#${file}}
			[ -e ${tfile} ] && continue

			if [ -d ${f} -a ! -L ${f} ] ; then
				mkdir -p ${tfile}
				continue
			else
				mkdir -p ${tfile%/*}
			fi

# 			if [ -b ${f} -o -c ${f} -o -p ${f} -o -L ${f} ] ; then
				cp -a ${f} ${tfile}
# 			else
# 				cp ${f} ${tfile}
# 			fi

			file -L ${f} | grep -q ELF || continue
			libs="${libs} `needed_libs ${f}`"
		done < <( find "${file}" )
	done < ${x}
done

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
tmptar="`mktemp`" ; tar cfT ${tmptar} /dev/null

for x in $( cd ../2nd_stage ; ls -d lib/modules/*/kernel/drivers/{scsi,net} )
do
	[ -e "../2nd_stage/${x}" ] && tar rf ${tmptar} -C ../2nd_stage ${x}
done
tar xf ${tmptar} ; rm -f ${tmptar}

[ -e lib/modules ] && find lib/modules -type f -exec $STRIP --strip-debug {} \;

for x in ../2nd_stage/lib/modules/*/modules.{dep,pcimap,isapnpmap} ; do
	cp $x ${x#../2nd_stage/} || echo_status "not found: $x" ;
done

for x in lib/modules/*/kernel/drivers/{scsi,net}; do
	[ -d $x ] && ln -s ${x#lib/modules/} lib/modules/
done
rm -f lib/modules/[0-9]*/kernel/drivers/scsi/{st,scsi_debug}.{o,ko}
rm -f lib/modules/[0-9]*/kernel/drivers/net/{dummy,ppp*}.{o,ko}

echo_status "Copying required libraries ... "
while [ -n "${libs}" ] ; do
	oldlibs=${libs}
	libs=""
	for x in ${oldlibs} ; do
		[ -e ${targetdir}/${x} ] && continue
		mkdir -p ${targetdir}/${x%/*}
		cp ${rootdir}/${x} ${targetdir}/${x}
		file -L ${rootdir}/${x} | grep -q ELF || continue
		for y in `needed_libs ${rootdir}/${x}` ; do
			[ ! -e "${targetdir}/${y}" ] && libs="${libs} ${y}"
		done
	done
done

echo_status "Creating links for identical files ..."
while read ck fn
do
	# don't link empty files...
	if [ "${oldck}" = "${ck}" -a -s "${fn}" ] ; then
		echo_status "\`- Found ${fn#${targetdir}} -> ${oldfn#${targetdir}}."
		rm ${fn} ; ln -s /${oldfn#${targetdir}} ${fn}
	else
		oldck=${ck} ; oldfn=${fn}
	fi
done < <( find ${targetdir} -type f | xargs md5sum | sort )

cd ..

echo_header "Creating initrd filesystem image (${initrdfs}): "
case "${initrdfs}" in
cramfs)
	[ "${block_size}" == "" ] && block_size=4096
	mkfs.cramfs -b ${block_size} ${targetdir} ${initrd_img}
	;;
ramfs)
#	cp -a ${targetdir}/{linuxrc,init}
	( cd ${targetdir} ; find | cpio -o -c > ${initrd_img} ; )
	;;	
ext2fs|ext3fs)
	[ "${block_size}" == "" ] && block_size=1024
	block_count=$(( ( 1024 * ${ramdisk_size} ) / ${block_size} ))

	echo_status "Creating temporary files."
	tmpdir=`mktemp -d` ; mkdir -p ${tmpdir}
	dd if=/dev/zero of=${initrd_img} bs=${block_size} count=${block_count} &> /dev/null
	tmpdev="`losetup -f 2>/dev/null`"
	if [ -z "${tmpdev}" ] ; then
		for x in /dev/loop* /dev/loop/* ; do
			[ -b "${x}" ] || continue
			losetup ${x} 2>&1 >/dev/null || tmpdev="${x}"
			[ -n "${tmpdev}" ] && break
		done
		if [ -z "${tmpdev}" ] ; then
			echo_status "No free loopback device found!"
			rm -f ${tmpfile} ; rmdir ${tmpdir}; exit 1
		fi
	fi
	echo_status "Using loopback device ${tmpdev}."
	losetup "${tmpdev}" ${initrd_img}

	echo_status "Writing initrd image file."
	mkfs.${initrdfs:0:4} -b ${block_size} -m 0 -N 360 -q ${tmpdev} &> /dev/null
	mount -t ${initrdfs:0:4} ${tmpdev} ${tmpdir}
	rmdir ${tmpdir}/lost+found/
	cp -a ${targetdir}/* ${tmpdir}
	umount ${tmpdir}
 
	echo_status "Removing temporary files."
	losetup -d ${tmpdev}
	rm -rf ${tmpdir}
	;;
esac

echo_status "Compressing initrd image file."
gzip -9 -c ${initrd_img} > ${initrd_img}.gz
mv ${initrd_img%.img}{.img,}.gz

target="$rock_target"
