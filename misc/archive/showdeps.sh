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

 -usedby : show only packages that depend on this package
 -uses   : show only packages this package depends on
 -missing: show only packages missing for this package

EOF
exit 1
}

uses=1
usedby=1
missing=1

while [ ${1:0:1} == "-" ] ; do
	case $1 in
		-usedby)
			uses=0
			missing=0
			shift
			;;	
		-uses)
			usedby=0
			missing=0
			shift
			;;
		-missing)
			usedby=0
			uses=0
			shift
			;;
	esac
done

if [ $usedby == 0 -a $uses == 0 -a $missing == 0 ] ; then usedby=1 ; uses=1 ; missing=0 ; fi

# auto-find sourcetree if none was given
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

list_missing_pkgs() {
	MISSING_PKGS="";
	for i in `grep "^$1: " ./scripts/dep_db.txt | cut -d" " -f4-` ; do
		[ $i == $1 -o $i == "x11" -o $i == "xfree86" ] && continue 
		if [ ! -f "/var/adm/packages/$i" -a ! -f  "/var/adm/packages/$i:dev" ] ; then
			MISSING_PKGS="$MISSING_PKGS $i"
		fi
	done
	echo $MISSING_PKGS
}

# recursive function
show_missing_pkgs() {
	MISSING_I=`list_missing_pkgs $1`;
	[ -z "$MISSING_I" ] && return ;
	# already shown ?
	[ "${SHOWNLIST/ $1 /}" != "$SHOWNLIST" ] && continue;
	SHOWNLIST="${SHOWNLIST}$1 "
	echo 
	echo "packages missing for $1:"
	print_nice $MISSING_I
	for i in $MISSING_I ; do
		[ -z "$i" ] && continue ;
		show_missing_pkgs $i
	done
}

if [ $missing == 1 ] ; then
	SHOWNLIST=" "
	show_missing_pkgs $1
fi
echo

