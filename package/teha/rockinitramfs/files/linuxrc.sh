#!/bin/sh
. /etc/profile
for x in /init.d/*
do
	. $x
done
echo "going real..."
if [ -x /real-root/sbin/init ]
then
	exec /sbin/run_init /real-root /sbin/init
else
	echo "no /real-root/sbin/init found. spawning /bin/bash..."
	exec /bin/bash --login
fi
