if any_installed "usr/bin/ssh-keygen" ; then
	if [ ! -f /etc/ssh/ssh_host_key ] ; then
		echo "Creating /etc/ssh/ssh_host_key"
		/usr/bin/ssh-keygen -t rsa1 -f /etc/ssh/ssh_host_key -N ''
	fi
	if [ ! -f /etc/ssh/ssh_host_dsa_key ] ; then
		echo "Creating /etc/ssh/ssh_host_dsa_key"
		/usr/bin/ssh-keygen -t dsa  -f /etc/ssh/ssh_host_dsa_key -N ''
	fi
	if [ ! -f /etc/ssh/ssh_host_rsa_key ] ; then
		echo "Creating /etc/ssh/ssh_host_rsa_key"
		/usr/bin/ssh-keygen -t rsa  -f /etc/ssh/ssh_host_rsa_key -N ''
	fi
fi

exit 0

if any_removed "usr/bin/ssh-keygen" ; then
	echo "Removing ssh host keys"
	rm -f /etc/ssh/ssh_host_key /etc/ssh/ssh_host_dsa_key /etc/ssh/ssh_host_rsa_key
fi
