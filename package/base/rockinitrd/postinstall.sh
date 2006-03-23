if any_installed "boot/initrd.img" ; then
	echo "Re-Creating initrd..."
	/sbin/mkinitrd
fi

