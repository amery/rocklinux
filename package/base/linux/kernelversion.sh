
# Older function from pcmcia-cs.conf
#
# get_kernel_modules_version() {
#       ls -d $root/lib/modules/[0-9]*.[0-9]*.[0-9]*/ | cut -f4 -d/ |
#       while read x ; do
#               x=${x//./)*1000+} ; y=${x//[^)]/}
#               echo $(( ${y//)/(}$x )) $x
#       done | sort -n | while read y x ; do
#               echo ${x//)\\*1000+/.}
#       done | tail -n 1
# }

getkernelversion() {
	if [ -f $root/usr/src/linux/Makefile ]; then
		make -s -C $root/usr/src/linux -f <( echo -e 'include Makefile\nprintversion:\n\t@echo $(KERNELRELEASE)' ) printversion
	else
		uname -r
	fi
}

add_uname_wrapper() {
	add_wrapper uname <<- EOT
		if [ "\$*" = "-r" ]; then
			echo "$kernelversion"
			exit 0
		fi
		exec \$orig "\$@"
	EOT
}

add_depmod_wrapper() {
	add_wrapper depmod <<- EOT
		exit 0
	EOT
}

kernelversion="$( getkernelversion )"

