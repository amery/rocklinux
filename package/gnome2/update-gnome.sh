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

for url in $urlplatform $urldesktop; do
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
		fi
	done
done
