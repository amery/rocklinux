#!/bin/sh
#
# [A] Tobias Hintze <th@rocklinux.org>
# [A] Thomas "fake" Jakobi <fake@rapidnetworks.de>
#
# todo: support multiple packages as arguments and
# combine common uses/usedby's

[ -z "$1" -o "$1" == "-help" ] && {
	cat <<EOF
usage: $0 [ -usedby | -uses ] PKG [ SOURCE_TREE ]

check \$SOURCE_TREE/scripts/dep_db.txt and print
dependencies and dependants of given package.

 -usedby: show only packages that depend on this package
 -uses  : show only packages this package depends on

EOF
exit 1
}

uses=1
usedby=1

while [ ${1:0:1} == "-" ] ; do
	case $1 in
		-usedby)
			uses=0
			shift
			;;	
		-uses)
			usedby=0
			shift
			;;
	esac
done

if [ $usedby == 0 -a $uses == 0 ] ; then usedby=1 ; uses=1 ; fi


if [ -n "$2" ] ; then
	SOURCE_TREE=$2
	if [ ! -f $SOURCE_TREE/scripts/dep_db.txt ] ; then
		echo "no $SOURCE_TREE/scripts/dep_db.txt found."
		exit 1
	fi
else
	if [ -f ./scripts/dep_db.txt ] ; then
		SOURCE_TREE=.
	else
		if [ -f /usr/src/rock-src/scripts/dep_db.txt ] ; then
			echo "using /usr/src/rock-src/scripts/dep_db.txt instead."
			SOURCE_TREE=/usr/src/rock-src
		else
			echo "no ./scripts/dep_db.txt found."
			exit 1
		fi
	fi
fi

cd $SOURCE_TREE

function print_nice() {
	CNT=0
	for pkg in $*
	do
		CNT=$(( $CNT+1 ));
		printf "%-15s" ${pkg:0:14}
		if [ $CNT -gt 3 ] ; then printf "\n" ; CNT=0 ; fi
	done 
	echo
}

if [ $uses == 1 ] ; then
	echo
	echo "$1 depends on:"
	print_nice `grep "^$1: " ./scripts/dep_db.txt | cut -d" " -f4-`
fi

if [ $usedby == 1 ] ; then
	echo
	echo "packages depending on $1:"
	print_nice `grep "\<$1\>" ./scripts/dep_db.txt | cut -d: -f1`
fi
echo

