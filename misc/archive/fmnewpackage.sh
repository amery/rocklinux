#!/bin/bash
#
# Written by Benjamin Schieder <blindcoder@scavenger.homeip.net>
# Modified by Juergen Sawinski <jsaw@gmx.net> to create
# a package based on freshmeat info
#
# Use:
# newpackage.sh [-main] <rep>/<pkg> <freshmeat package name>
#
# will create <pkg>.desc and <pkg>.conf. .desc will contain the [D] and [COPY]
# already filled in. The other tags are mentioned with TODO.
#
# .conf will contain an empty <pkg>_main() { } and custmain="<pkg>_main"
# if -main is specified.
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/misc/archive/fmnewpackage.sh
# ROCK Linux is Copyright (C) 1998 - 2003 Clifford Wolf
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. A copy of the GNU General Public
# License can be found at Documentation/COPYING.
# 
# Many people helped and are helping developing ROCK Linux. Please
# have a look at http://www.rocklinux.org/ and the Documentation/TEAM
# file for details.
# 
# --- ROCK-COPYRIGHT-NOTE-END ---
#

extract_xml_name() {
    local tmp="`tr -d "\012" < $2 | grep $3 | sed "s,.*<$3>\([^<]*\)<.*,\1," | sed 's,,\n[T] ,g' | sed 's,^\[T\] $,,'`"
    eval "$1=\"\$tmp\""
}

get_download() {
    local location
    download_file=""
    download_url=""
set -x
    for arg; do
	if curl -I -f "$arg" -o "header.log"; then
	    location="`grep Location: header.log | sed 's,Location:[ ]\([.0-9A-Za-z-:/% ]*\).*,\1,'`"
	    download_file="`basename $location`"
	    download_url="`dirname $location`/"
	    rm -f header.log
	    set +x
	    return
	fi
    done
    set +x
    rm -f header.log
}

read_fm_config() {
    local fmname=$1
    curl_options="" #--disable-epsv 
    if curl -w '\rFinished downloading %{size_download} bytes in %{time_total} seconds (%{speed_download} bytes/sec). \n' -f --progress-bar $resume $curl_options "http://freshmeat.net/projects-xml/$fmname/$fmname.xml" -o "$fmname.xml"; then
	extract_xml_name project $fmname.xml projectname_full
	extract_xml_name title   $fmname.xml desc_short
	extract_xml_name desc    $fmname.xml desc_full
	extract_xml_name url     $fmname.xml url_project_page
	extract_xml_name status  $fmname.xml branch_name
	extract_xml_name license $fmname.xml license
	extract_xml_name version $fmname.xml latest_version

	extract_xml_name url_tbz $fmname.xml url_bz2
	extract_xml_name url_tgz $fmname.xml url_tgz
	extract_xml_name url_zip $fmname.xml url_zip
	extract_xml_name url_cvs $fmname.xml url_cvs

	get_download $url_tbz $url_tgz $url_zip #@FIXME $url_cvs 

	#cleanup some variables
	case "$status" in
	Alpha|Beta|Gamma|Stable)
	    ;;
	*)
	    status="TODO: Unknown ($status)"
	    ;;
	esac	 

	case "$license" in
	*GPL*Library*)
	    license=LGPL
	    ;;
	*GPL*Documentation*)
	    license=FDL
	    ;;
	*GPL*)
	    license=GPL
	    ;;
	*Mozilla*Public*)
	    license=MPL
	    ;;
	*MIT*)
	    license=MIT
	    ;;
	*BSD*)
	    license=BSD
	    ;;
	*)
	    license="TODO: Unknown ($license)"
	    ;;
	esac
	rm -f $fmname.xml
    else
	return 1
    fi
}

if [ "$1" == "-main" ] ; then
	create_main=1
	shift
fi

if [ $# -lt 2 -o $# -gt 2 ] ; then
	cat <<-EEE
Usage:
$0 <option> package/repository/packagename freshmeat-package-name

Where <option> may be:
	-main		Create a package.conf file with main-function

	EEE
	exit 1
fi


dir=${1#package/} ; shift
package=${dir##*/}
if [ "$package" = "$dir" ]; then
	echo "failed"
	echo -e "\t$dir must be <rep>/<pkg>!\n"
	exit
fi

rep="$( echo package/*/$package | cut -d'/' -f 2 )"
if [ "$rep" != "*" ]; then
	echo "failed"
	echo -e "\tpackage $package belongs to $rep!\n"
	exit
fi

echo -n "Creating package/$dir ... "
if [ -e package/$dir ] ; then
	echo "failed"
	echo -e "\tpackage/$dir already exists!\n"
	exit
fi
if mkdir -p package/$dir ; then
	echo "ok"
else
	echo "failed"
	exit
fi

cd package/$dir
rc="ROCK-COPYRIGHT"

if ! read_fm_config $1; then
    echo "Error or wrong freshmeat package name"
    exit 1
fi

echo -n "Creating $package.desc ... "
cat >>$package.desc <<EEE

[COPY] --- ${rc}-NOTE-BEGIN ---
[COPY] 
[COPY] This copyright note is auto-generated by ./scripts/Create-CopyPatch.
[COPY] Please add additional copyright information _after_ the line containing
[COPY] the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
[COPY] the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
[COPY] 
[COPY] ROCK Linux: rock-src/package/$dir/$package.desc
[COPY] ROCK Linux is Copyright (C) 1998 - `date +%Y` Clifford Wolf
[COPY] 
[COPY] This program is free software; you can redistribute it and/or modify
[COPY] it under the terms of the GNU General Public License as published by
[COPY] the Free Software Foundation; either version 2 of the License, or
[COPY] (at your option) any later version. A copy of the GNU General Public
[COPY] License can be found at Documentation/COPYING.
[COPY] 
[COPY] Many people helped and are helping developing ROCK Linux. Please
[COPY] have a look at http://www.rocklinux.org/ and the Documentation/TEAM
[COPY] file for details.
[COPY] 
[COPY] --- ${rc}-NOTE-END ---

[I] $title

[T] $desc

[U] $url

[A] TODO: Author
[M] TODO: Maintainer

[C] TODO: Category

[L] $license
[S] $status
[V] $version
[P] X -----5---9 800.000

[D] 0 $download_file $download_url
EEE

echo "ok"
echo -n "Creating $package.conf ... "

if [ "$create_main" == "1" ] ; then
	cat >>$package.conf <<-EEE

# --- ${rc}-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/$dir/$package.conf
# ROCK Linux is Copyright (C) 1998 - `date +%Y` Clifford Wolf
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. A copy of the GNU General Public
# License can be found at Documentation/COPYING.
# 
# Many people helped and are helping developing ROCK Linux. Please
# have a look at http://www.rocklinux.org/ and the Documentation/TEAM
# file for details.
# 
# --- ${rc}-NOTE-END ---

	EEE
	cat >>$package.conf <<-EEE
${package}_main() { #TODO
}

custmain="${package}_main"
	EEE
fi

echo "ok"
echo "Remember to fill in the TODO's:"
cd -
grep TODO package/$dir/$package.*
echo
