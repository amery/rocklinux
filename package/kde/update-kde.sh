#!/bin/bash

if [ ! "$1" -o ! "$2" ] ; then
	echo "You must specify old and new version ..."
	exit -1
fi

for x in kde* ; do
	echo "Updating $x ..."
	sed 	-e s,$1,$2,g \
		-e "s/\[D\] [0-9]* /\[D\] 0 /" $x/$x.desc > $x/$x.desc.new
	mv $x/$x.desc.new $x/$x.desc
done

x="arts"
echo "Updating $x ..."
sed 	-e s,1.${1:2},1.${2:2},g \
	-e "s/\[D\] [0-9]* /\[D\] 0 /" $x/$x.desc > $x/$x.desc.new
mv $x/$x.desc.new $x/$x.desc
