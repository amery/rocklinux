#!/bin/bash

update=0
[ "$2" == "-update" ] && update=1

xver="$1" # e.g. X11R7.1
URL="ftp://ftp.gwdg.de/pub/x11/x.org/pub/$xver/src/"

top_prio="110.800"

prio_to_num() {
	echo ${1/.}
}
num_to_prio() {
	echo "${1:0:3}.${1:3:3}"
}
prio_plus() {
	num_to_prio $(( `prio_to_num $top_prio` + $1 ))
}

curl -l "$URL" |
while read N ; do 
	N="${N%?}"
	[ "$N" == "everything" ] && continue
	echo "$URL$N/"
	curl -l "$URL$N/" | 
	while read P ; do 
		P="${P%?}"
		[[ "$P" = *bz2 ]] || continue
		P="${P%.tar.bz2}"
		pname="${P%%-$xver-*}"
		lowpname="`echo $pname | tr '[A-Z]' '[a-z]'`"
		pver="${P##*-$xver-}"

		if [ "$update" = 0 ] ; then
			rm -rf package/xorg/"$lowpname"
			misc/archive/newpackage.sh package/xorg/"$lowpname" "$URL$N/$P.tar.bz2"

			case "$lowpname" in
			util-macros) 		delta=0 ;;
			xorg-sgml-doctools) delta=1 ;;
			xorg-docs) 		delta=2 ;;
			*proto*|evieext)	delta=3 ;;
			xtrans) 		delta=4 ;;
			libxau) 		delta=5 ;;
			libxdmcp) 		delta=6 ;;
			libx11) 		delta=8 ;;
			libxext) 		delta=10 ;;
			libapplewm|libwindowswm|libdmx|libfontenc)
						delta=12 ;;
			libfs|libice|liblbxutil|liboldx)
						delta=14 ;;
			libsm)			delta=16 ;;
			libxt)			delta=18 ;;
			libxmu|libxpm)		delta=20 ;;
			libxp|libxaw|libxfixes)	delta=22 ;;
			libxrender)		delta=23 ;;
			libxcomposite|libxdamage|libxcursor|libxevie|`
			`libxfont|libxfontcache|libxft|libxi|libxinerama|libxkbfile|libxkbui)
						delta=24 ;;
			libxprintutil)		delta=25 ;;
			libxprintapputil|libxrandr|libxres|libxscrnsaver|libxtrap|`
			`libxtst|libxv|libxvmc|libxxf86dga|libxxf86misc|libxxf86vm)
						delta=26 ;;
			xbitmaps)		delta=28 ;;
			# alls apps are delta=30, see below.
			xorg-server) 		delta=32 ;;
			xf86-input*) 		delta=34 ;;
			xf86-video*) 		delta=36 ;;
			xcursor-themes|xkbdata)	delta=50 ;;
			font-util)		delta=55 ;;
			font-*)			delta=60 ;;
			xorg-cf-files|imake|makedepend|gccmakedep|lndir)
						delta=70 ;;
			*)			delta=99 ;;
			esac
			[ "$N" == "app" ] && delta=30 
		fi

		sed -i -e"s,\[V\].*,\[V\] $pver," package/xorg/"$lowpname"/"$lowpname".desc

		if [ "$update" = 0 ] ; then		
		sed -i -e"s,\[P\] \(.*\) ...\....,\[P\] \1 `prio_plus $delta`," package/xorg/"$lowpname"/"$lowpname".desc
		sed -i -e"s,\[U\].*,\[U\] http://www.x.org," package/xorg/"$lowpname"/"$lowpname".desc
		sed -i -e"s,\[S\].*,\[S\] Stable," package/xorg/"$lowpname"/"$lowpname".desc
		sed -i -e"s,\[L\].*,\[L\] OpenSource," package/xorg/"$lowpname"/"$lowpname".desc
		sed -i -e"s,\[I\].*,\[I\] X.Org X11 $pname component," package/xorg/"$lowpname"/"$lowpname".desc
		sed -i -e"s,\[C\].*,\[C\] base/x11\n\[F\] CORE," package/xorg/"$lowpname"/"$lowpname".desc
		sed -i -e"s:\[T\].*:\[T\] The $pname component for the X.Org Foundation X11 Release 7 and above.:" package/xorg/"$lowpname"/"$lowpname".desc
		sed -i -e"s:\[A\].*:\[A\] The X.Org Foundation {The X.Org Sourcecode}\n[A] The Open Group X Project Team {Original Sourcecode}:" package/xorg/"$lowpname"/"$lowpname".desc
		else
			sed -i -e"s,\[D\].*,\[D\] 0 $P.tar.bz2 $URL$N," package/xorg/"$lowpname"/"$lowpname".desc
		fi

		uniq -c package/xorg/"$lowpname"/"$lowpname".desc | cut -f8- -d" " > tmp.desc
		mv tmp.desc package/xorg/"$lowpname"/"$lowpname".desc

		echo '. "$base/package/xorg/xorg_config.sh"' > package/xorg/"$lowpname/$lowpname.conf"
	done
done
