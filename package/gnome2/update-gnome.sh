#!/bin/sh

#
# Usage: update-gnome.sh [-n] gnome-version
# 
#   -n prints the package that will be updated with their new versions
#      without making any changes
#

dry=0
if [ "$1" = "-n" ] ; then
	dry=1
	shift
fi

ver=$1
major="${ver%.*}"
rev="${ver##*.}"

baseurl="http://ftp.gnome.org/pub/GNOME"
urlplatform="$baseurl/platform/$major/$major.$rev/sources/"
urldesktop="$baseurl/desktop/$major/$major.$rev/sources/"
urlbindings="$baseurl/bindings/$major/$major.$rev/sources"
urlbindings="$urlbindings/c++/ $urlbindings/java/ $urlbindings/mono/ $urlbindings/python/"
urladmin="$baseurl/admin/$major/$major.$rev/sources/"

for url in $urlplatform $urldesktop $urlbindings $urladmin; do
	wget -q -O - $url | \
	sed -n '/id="body"/,/\/div/{/tar.bz2/p}' | \
	sed -r 's/^.*href="([^"]*).tar.bz2".*$/\1/' | \
	tr 'A-Z' 'a-z' | \
	sed -e 's/gtk-doc/gtkdoc/' -e 's/libart_lgpl/libart_lgpl23/' | \
	while read newver; do
		pkg="${newver%-*}"
		pkgver="${newver##*-}"
		if [ -d package/*/$pkg ]; then
			if [ $dry = 1 ] ; then
				echo $pkg-$pkgver
			else
				./scripts/Create-PkgUpdPatch $pkg-$pkgver | \
				patch -p0
			fi
		else
			echo "$pkg is not a rock package yet"
# 			echo "creating $pkg package"
# 			bash misc/archive/newpackage.sh package/gnome2/$pkg $url$newver.tar.bz2
		fi
		if [ -e package/*/$pkg/$pkg.desc -a $dry = 0 ] ; then
			sed -i -e "s,^\(\[D\] .*$newver.* \)http://.*,\1$url,g" package/*/$pkg/$pkg.desc
		fi
	done
done

grep "^\[D\] .* http://ftp.gnome.org/pub/GNOME/sources/" package/gnome2/*/*.desc | \
while IFS=":" read pkg download; do
 	pkg=${pkg##*/} ; pkg=${pkg%.desc}

	read dtag cksum file durl < <(echo $download)
	durl="${durl%/}" ; durl="${durl%/*}"

	wget -q -O - $durl | \
	sed -n -e 's,.*href="\([0-9.].*\)".*,\1,gp' | \
	tail -n1 | \
	while read newmajor ; do
		url="$durl/$newmajor"

		wget -q -O - $url | \
		sed -n -e"s,.*\(LATEST-IS-[^<]*\).*,\1,gp" | \
		while read newver; do
			pkgver="${newver#LATEST-IS-}"

			if [ -d package/*/$pkg ]; then
				if [ $dry = 1 ] ; then
					echo $pkg-$pkgver
				else
					./scripts/Create-PkgUpdPatch $pkg-$pkgver | \
					patch -p0
				fi
			else
				echo "$pkg is not a rock package yet"
# 				echo "creating $pkg package"
# 				bash misc/archive/newpackage.sh package/gnome2/$pkg $url$newver.tar.bz2
			fi
			if [ -e package/*/$pkg/$pkg.desc -a $dry = 0 ] ; then
				sed -i -e "s,^\(\[D\] .*$pkgver.* \)http://.*,\1$url,g" package/*/$pkg/$pkg.desc
			fi
	 	done
	done
done
