#!/bin/sh
exec 2>&1

verbose=0
quiet=0
source=
targets=
repositories=
packages=

function show_usage() {
	echo "usage: $0 [-q] [-v] <source> <target> [-repository <repo>|<packages>|]"
	echo "usage: $0 [-q] -3 <source> <target1> <target2> [-repository <repo>|<packages>|]"
}

# TODO: it would be great to port it to "-n <n>" instead of -3
#
while [ $# -gt 0 ]; do
	case "$1" in
		-v)	verbose=1	;;
		-q)	quiet=1		;;
		-3)	source="$2"
			targets="$3 $4"
			shift 3		;;
		-repository) 
			shift
			repositories="$*"; set -- 
			;;
		*)	if [ "$targets" ]; then
				packages="$*"; set --
			elif [ "$source" ]; then
				targets="$1"
			else
				source="$1"
			fi
	esac
	shift
done
			
#if [ $verbose -eq 1 ]; then
#	echo "   verbosity: $verbose"
#	echo "      source: $source"
#	echo "     targets: $targets"
#	echo "repositories: $repositories"
#	echo "    packages: $packages"
#fi 1>&2

function diff_package() {
	local source="$1"
	local target="$1"

	# files on source
	for x in $source/*; do
		if [ -d "$x" ]; then
			diff_package $x $target/${x##*/}
		elif [ -f $x -a -f $target/${x##*/} ]; then
			echo diff -u $x $target/${x##*/}
		else
			echo diff -u $x /dev/null
		fi
	done
	# TODO: files only on target
}

# grabdata confdir field
function grabdata() {
	local confdir=$1
	local pkg=$2
	local field=$3
	local output=

	case "$field" in
		version)	output=$( grabdata_desc $confdir/$pkg.desc $field ) ;;
		*)		output=$( grabdata_cache $confdir/$pkg.cache $field ) ;;
	esac
	if [ -z "${output// /}" ]; then
		echo "UNKNOWN"
	else
		echo "$output"
	fi
}
function grabdata_desc() {
	local output=
	if [ -f "$1" ]; then
		case "$2" in
			version)	output=$( grep -e "^\[V\]" $1 | cut -d' ' -f2- )	;;
		esac
	fi
	echo "$output"
}
function grabdata_cache() {
	local output=
	if [ -f "$1" ]; then
		case "$2" in
			status)	if grep -q -e "^\[.-ERROR\]" $1; then
					output=BROKEN
				else
					output=BUILT
				fi	;;
			size)	output=$( grep -e "^\[SIZE\]" $1 | cut -d' ' -f2- )	;;
		esac
	fi
	echo "$output"
}
function compare_package() {
	local pkg=${1##*/}
	local source=$1
	local target= x= missing=0
	shift;

	srcver=$( grabdata $source $pkg version )
	srcstatus=$( grabdata $source $pkg status )
	srcsize=$( grabdata $source $pkg size )
	tgtver=
	tgtstatus=
	tgtsize=

	for x; do
		target=$( echo $x/package/*/$pkg | head -n 1 )
		if [ -d "$target" ]; then
			tgtver="$tgtver:$( grabdata $target $pkg version )"
			tgtstatus="$tgtstatus:$( grabdata $target $pkg status )"
			tgtsize="$tgtsize:$( grabdata $target $pkg size )"
		else
			tgtver="$tgtver:MISSING"
			tgtstatus="$tgtstatus:MISSING"
			tgtsize="$tgtsize:MISSING"
			missing=1
		fi
	done
	
	tgtver="${tgtver#:}"
	tgtstatus="${tgtstatus#:}"
	tgtsize="${tgtsize#:}"

	equalver=1 equalstatus=1
	IFS=':' ; for x in $tgtver; do
		[ "$x" != "$srcver" ] && equalver=0
	done
	IFS=':' ; for x in $tgtstatus; do
		[ "$x" != "$srcstatus" ] && equalstatus=0
	done

	if [ $equalver -eq 1 ]; then
		version=$srcver
	else
		version="$srcver -> $tgtver"
	fi
	
	if [ $equalstatus -eq 1 ]; then
		status="$srcstatus"
	else
		status="$srcstatus -> $tgtstatus"
	fi
	
	if [ $missing -eq 1 ]; then
		echo "- $pkg ($version) ($status) ($srcsize -> $tgtsize)" 1>&2
	elif [ $equalver -eq 1 ]; then
		[ $quiet -eq 0 ] && echo "* $pkg ($version) ($status) ($srcsize -> $tgtsize)" 1>&2
	else
		echo "+ $pkg ($version) ($status) ($srcsize:$tgtsize)" 1>&2
		[ "$verbose" -eq 1 ] && diff_package $source $target
	fi
}

if [ -z "$source" -o -z "$targets" ]; then
	show_usage; exit 1
fi

allexist=1
for x in $source $targets; do
	[ ! -d "$x/" ] && allexist=0; break
done

if [ $allexist -eq 1 ]; then
	echo -e "from: $source\nto..: $targets" 1>&2

	if [ "$repositories" ]; then
		for repo in $repositories; do
			for x in $source/package/$repo/*; do
				[ -d "$x" ] && ( compare_package $x $targets )
			done
		done
	elif [ "$packages" ]; then
		for pkg in $packages; do
			x=$( echo $source/package/*/$pkg | head -n 1 )
			[ -d "$x" ] && compare_package $x $targets
		done
	else
		for repo in $source/package/*; do
			echo "repository: ${repo##*/}" 1>&2
			for x in $repo/*; do
				[ -d "$x" ] && compare_package $x $targets
			done
		done
	fi
else
	show_usage
	exit 1
fi

