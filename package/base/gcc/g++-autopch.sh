#!/bin/bash
#
# AutoPCH: Automatically use pre-compiled headers
#
# Simply use this script instead of calling g++ directly.
# This is a dirty hack. So don't wonder if it does not work
# out of the box with every package.
#
# example using kdegames:
# -----------------------
#
# time make CXX="autopch"
# real    30m41.945s
# user    25m30.924s
# sys     3m9.300s
#
# without autopch:
# real    42m59.061s
# user    36m50.630s
# sys     2m41.806s


cxx="${AUTOPCHCXX:-g++}"
cppfile="$( echo "$*" | sed -r 's,.* ([^ ]*\.cpp).*,\1,'; )"
cppargs="$( echo "$*" | sed -r 's, ([^- ]|-[MCSEco])[^ ]*,,g'; )"

# echo "AutoPCH> $cxx $*" >&2
# echo "AutoPCH - cppfile> $cppfile" >&2
# echo "AutoPCH - cppargs> $cppargs" >&2

if [ ".$cppfile" == ".$*" ]; then
	exec $cxx "$@"
	exit 1
fi

if [ ! -f autopch.h -a ! -f autopch_oops.h ]; then
	{
		echo "#ifndef _AUTOPCH_H_"
		echo "#define _AUTOPCH_H_"
		echo "#warning AutoPCH: THEWARNING"
		[ -f autopch_incl.h ] && cat autopch_incl.h
		egrep -h '^#(include.*\.h[">]|if|endif|define.*[^\\]$|undef)' *.cpp | \
			egrep -v "[<\"](${AUTOPCHEXCL:-autopch.h})[\">]"
		echo "#endif /* _AUTOPCH_H_ */"
	} > autopch.h.plain
	sed 's,THEWARNING,New pre-compiled header.,' < autopch.h.plain > autopch.h
	echo "exec $cxx -I. $cppargs -x c++ -c autopch.h" > autopch.sh
	if ! sh autopch.sh; then mv -f autopch.h autopch_oops.h; fi
	sed 's,THEWARNING,Pre-compiled header not used!,' < autopch.h.plain > autopch.h
fi

if ! test -f autopch.h || ! $cxx -include autopch.h "$@"; then
	echo "AutoPCH: Fallback to non pre-compiled headers!" >&2
	exec $cxx "$@"
	exit 1
fi
exit 0

