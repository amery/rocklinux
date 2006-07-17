# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/x11/xorg/xf_config.sh
# ROCK Linux is Copyright (C) 1998 - 2006 Clifford Wolf
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

# extract and patch base
xf_extract() {
	echo "Extracting source (for package version $ver) ..."
	for x in $xf_files ; do
		tar $taropt $archdir/$x
	done

	cd xc

	for x in $xf_patches ; do
		echo "Patching source ($x) ..."
        	bunzip2 < $archdir/$x | patch -p1 -E
	done
}

# extract additional gl* stuff
xf_extract_gl() {
	mkdir release ; ln -s ../.. release/xc
	tar $taropt $archdir/mangl.tar.bz2
	tar $taropt $archdir/manglu.tar.bz2
	tar $taropt $archdir/manglx.tar.bz2
	rm -rf release
}

# extract the Matrox HALlib (additional TV/DVI out support on x86)
xf_extract_hallib() {
	echo "Extracting mgaHALlib (For Matrox (>G400) cards) ..."
	tar $taropt $archdir/mgadriver-$mga_version-src.tar.bz2
	cp mgadriver-$mga_version-src/4.3.0/mga/HALlib/mgaHALlib.a \
	  programs/Xserver/hw/xfree86/drivers/mga/HALlib/mgaHALlib.a
	rm -rf mgadriver-$mga_version-src 

	if [[ $arch == "x86" && $arch_machine != "x86_64" ]] ; then
		echo "Enabling Matrox HALlib (since this is x86) ..."
		cat >> config/cf/host.def << EOT

/* Additinal TC/DVI support since this is x86 */
#define         HaveMatroxHal           YES
EOT
	fi
}

# apply the patches
xf_patch() {
	cp -v programs/twm/system.twmrc programs/twm/system.twmrc.orig
	for x in $patchfiles ; do
	  if [ -f $x ] ; then
		echo "Apply patch $x ..."
		patch -Nf -p1 < $x
	fi ; done
	find \( -name 'config.guess' -o -name 'config.sub' \) \
		-exec chmod +x '{}' ';'
}

# build the World
xf_build() {
	eval $MAKE World
	cd nls ; eval $MAKE ; cd ..
}

# install the World
xf_install() {
	echo "Create /etc/X11 (if it's not already there) ..."
	mkdir -p $root/etc/X11

	if [ "$arch_sizeof_char_p" = 8 ] ; then
		mkdir -p $root/usr/X11R6/lib
		ln -s lib $root/usr/X11R6/lib64
	fi

	eval $MAKE install
	eval $MAKE install.man
	cd nls ; eval $MAKE install ; cd ..
	rm -fv $root/etc/fonts/*.bak

	rm -fv $root/usr/X11
	rm -fv $root/usr/bin/X11
	rm -fv $root/usr/lib/X11
	rm -fv $root/usr/include/X11

	ln -sv X11R6 $root/usr/X11
	ln -sv ../X11/bin $root/usr/bin/X11
	ln -sv ../X11/lib/X11 $root/usr/lib/X11
	ln -sv ../X11/include/X11 $root/usr/include/X11

	mkdir -p $root/usr/X11R6/lib/X11/fonts/TrueType
	
	echo "Copy TWM config files ..."
	cp -v programs/twm/system.twmrc.orig \
	  programs/twm/sample-twmrc/original.twmrc
	cp -v programs/twm/sample-twmrc/*.twmrc $root/usr/X11R6/lib/X11/twm/
	register_wm twm TWM /usr/X11/bin/twm

	echo "Copying default example configs ..."
	        cp -fv $base/package/x11/${pkg}/xorg.conf.data \
			$root/etc/X11/xorg.conf.example
		cp -fv $root/etc/X11/xorg.conf{.example,}
		cp -fv $base/package/x11/${pkg}/local.conf.data \
			$root/etc/fonts/local.conf

	echo "Fixing compiled keymaps directory ..."
	mkdir -p $root/var/lib/xkb 
	cp -fu programs/xkbcomp/compiled/README $root/var/lib/xkb

	echo "Installing xfs init script ..."
	install_init xfs $base/package/x11/${pkg}/xfs.init

	register_xdm xdm 'X11 dislay manager' /usr/X11R6/bin/xdm


	echo "Installing the xdm start script (multiplexer) ..."
	cp $confdir/startxdm.sh $root/usr/X11R6/bin/startxdm
	chmod +x $root/usr/X11R6/bin/startxdm

	echo "Installing X-Windows Setup Script ..."
	cp -fv $base/package/x11/${pkg}/stone_mod_${pkg}.sh $root/etc/stone.d/mod_${pkg}.sh
	echo "export WINDOWMANAGER=kde" > $root/etc/profile.d/windowmanager

	echo "Installing X-Windows Cron Script ..."
	cp -fv $base/package/x11/${pkg}/${pkg}.cron \
		$root/etc/cron.daily/80-${pkg}
	chmod +x $root/etc/cron.daily/80-${pkg}
}

# configure the World
xf_config() {
	if [ -f "$base/config/$config/xorgsite.def" ] ; then
		cp $base/config/$config/xorgsite.def config/cf/host.def
		echo "Found custom configuration"
	else
	
	echo "Configuring X-Windows ..."
	cat >> config/cf/host.def << EOT
/* Disable the internal zlib to use the system installed one */
#define		HasZlib			YES
/* Disable the internal expat library to use the system installed one */
#define		HasExpat		YES

/* Less warnings with recent gccs ... */
#define		DefaultCCOptions	-ansi GccWarningOptions

/* Make sure config files are allways installed ... */
#define		InstallXinitConfig	YES
#define		InstallXdmConfig	YES
#define		InstallFSConfig		YES

/* do not install duplicate crap in /etc/X11 */
#define		UseSeparateConfDir	NO

EOT
	
	if [[ $arch == "x86" && $arch_machine != "x86_64" ]] ; then
	        echo "Enabling Matrox HALlib (since this is x86) ..."
		cat >> config/cf/host.def << EOT

/* Additional TV/DVI support since this is x86 */
#define		HaveMatroxHal		YES
EOT
	fi
	
	fi
}

