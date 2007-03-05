#!/bin/bash
#
# Usage:
# cd package/xorg && bash xorg-update.sh X11R7.1

xver="$1"
URL="ftp://ftp.gwdg.de/pub/x11/x.org/pub/$xver/src"

module_list=""

while read N
do
	N="${N%?}"
	[ "$N" == "update" ] && continue
	[ "$N" == "deprecated" ] && continue
	[ "$N" == "everything" ] && continue

	echo "Checking $URL/$N/ .."

	while read P
	do 
		P="${P%?}"
		[[ "$P" = *bz2 ]] || continue

		pname="`echo $P | tr '[A-Z]' '[a-z]'`"
		pname="${pname%.tar.bz2}"
		pver="${pname#*-x11r*-}"
		pname="${pname%-x11r*}"

		if [ ! -f "$pname/$pname.desc" ]; then
			echo "Not found: $pname/$pname.desc ($N) [$lowxver]"
		else
			if ! egrep -q "^\[V\] $pver( |\$)" "$pname/$pname.desc"; then
				sed -i -e"s,\[V\].*,[V] $pver," "$pname/$pname.desc"
			fi
			if ! egrep -q "^\[D\] .* $P " "$pname/$pname.desc"; then
				sed -i -e"s,\[D\].*,\[D\] 0 $P $URL/$N," "$pname/$pname.desc"
			fi
		fi

		module_list="$module_list $pname"

	done < <( curl -s -S -l "$URL/$N/"; )
done < <( curl -s -S -l "$URL/"; )

for pkg in *
do
	[ -d "$pkg" ] || continue
	[ "$pkg" = "mesalib" ] && continue

	if grep -qv " $pkg " <( echo "$module_list "; ); then
		echo "Not found on FTP server: $pkg"
	fi
done

