#!/bin/bash

base="../../.."
pkg="kde4-l10n"
download_url='ftp://ftp.kde.org/pub/kde/stable/$desc_V/src/kde-l10n/'

. $base/scripts/functions

PATH="$base/src:$PATH"
parse_desc $pkg.desc || exit 1

eval download_url="$download_url"

rm -f $pkg.desc.new pkgmapper.in.new hosted.cfg.new

pkg="$pkg" $base/src/descparser < $pkg.desc > $pkg.desc.new || exit 1

echo "# automatically generated by $0" >> $pkg.desc.new
echo "# automatically generated by $0" >> hosted.cfg.new
echo "# automatically generated by $0" >> pkgmapper.in.new
echo 'case $xpkg in' >> pkgmapper.in.new

echo curl -l --disable-epsv -s $download_url/
curl -l --disable-epsv -s $download_url/ |
egrep "^kde-l10n-.*\.tar\.bz2" |
while read file ; do
	echo $file

	filever="${file#kde-l10n-}"
	filever="${filever%.tar.bz2*}"
	lang="${filever%%-*}"
	filever="${filever#$lang-}"

	{
		echo "#if xpkg == $pkg-$lang"
		echo "[I] KDE translations for the \"$lang\" locale."
		echo "[D] 0 kde-l10n-$lang-$filever.tar.bz2 $download_url"
		echo "#endif"
	} >> $pkg.desc.new

	forkopts="`grep "^$pkg-$lang " hosted.cfg.in | cut -f2- -d" "`"
	echo "pkgfork $pkg $pkg-$lang status O version $filever $forkopts" >> hosted.cfg.new

	echo "$pkg-$lang) pkg=$pkg ;;" >> pkgmapper.in.new
done

echo 'esac' >> pkgmapper.in.new

for file in $pkg.desc.new pkgmapper.in.new hosted.cfg.new ; do
	mv $file ${file%.new}
done
