
public_dhcp() {
	addcode up   5 5 "/sbin/dhclient -q $if"
	addcode down 5 5 "/sbin/dhclient -r $if"
}

