# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/sysfiles/stone_mod_general.sh
# ROCK Linux is Copyright (C) 1998 - 2004 Clifford Wolf
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
# [MAIN] 10 general,main Various general system configurations

set_keymap() {
	keymap=$(ls -l /etc/default.keymap 2> /dev/null | sed 's,.*/,,')
	[ -z "$keymap" ] && keymap="none" ; keymap="${keymap%.map.gz}"

	case "`uname -m`" in
	  i*86)
		mapdir="`echo /usr/share/kbd/keymaps/i386`"
		;;
	  ppc)
		mapdir="`echo /usr/share/kbd/keymaps/mac`" # ppc is a symlink
		;;
	  sparc*)
		mapdir="`echo /usr/share/kbd/keymaps/sun`"
		;;
	  *)
		gui_message "Can't auto-detect your architecture and so I can't find the right /usr/share/kbd/keymaps sub-directory for your system. Sorry."
		return
		;;
	esac

	cmd="gui_menu 'general_keymap' 'Select one of the"
	cmd="$cmd following keyboard mappings. (Current: $keymap)'"
	cmd="$cmd 'none (kernel defaults)' 'rm -f /etc/default.keymap ; loadkeys defkeymap'"

	cmd="$cmd $( find $mapdir -type f ! -path '*/include/*' -name '*.map.gz' -printf '%P\n' | sed 's,\(.*\)/\(.*\).map.gz$,"\2	(\1)" "ln -sf '$mapdir'/& /etc/default.keymap ; loadkeys \2",' | expand -t30 | sort | tr '\n' ' ')"

	eval "$cmd"
}

set_vcfont() {
	vcfont=$(ls -l /etc/default.vcfont 2> /dev/null | sed 's,.*/,,')
	if [ -z "$vcfont" ] ; then vcfont="none"
	else vcfont="`echo $vcfont | sed -e "s,\.\(fnt\|psf.*\)\.gz$,,"`" ; fi
	fontdir="/usr/share/kbd/consolefonts"

	cmd="gui_menu 'general_vcfont' 'Select one of the"
	cmd="$cmd following console fonts. (Current: $vcfont)'"
	cmd="$cmd 'none (kernel defaults)' 'rm -f /etc/default.vcfont ; setfont'"

	cmd="$cmd $( find $fontdir -type f \( -name '*.fnt.gz' -or -name '*.psf*.gz' \) -printf '%P\n' | sed 's,\(.*\).\(fnt\|psf.*\)\.gz$,"\1" "ln -sf '$fontdir'/& /etc/default.vcfont ; setfont \1",' | expand -t30 | sort | tr '\n' ' ')"

	eval "$cmd"
}

store_kbd(){
	if [ -f /etc/conf/kbd ] ; then
		sed -e "s/kbd_rate=.*/kbd_rate=$kbd_rate/" \
		    -e "s/kbd_delay=.*/kbd_delay=$kbd_delay/" < /etc/conf/kbd \
		  > /etc/conf/kbd.tmp
		grep -q kbd_rate= /etc/conf/kbd.tmp || echo kbd_rate=$kbd_rate \
		  >> /etc/conf/kbd.tmp
		grep -q kbd_delay= /etc/conf/kbd.tmp || echo kbd_delay=$kbd_delay \
		  >> /etc/conf/kbd.tmp
		mv /etc/conf/kbd.tmp /etc/conf/kbd
	else
		echo -e "kbd_rate=$kbd_rate\nkbd_delay=$kbd_delay\n" \
		  > /etc/conf/kbd
	fi
	[ "$kbd_rate" -a "$kbd_delay" ] && kbdrate -r $kbd_rate -d $kbd_delay
}

set_kbd_rate() {
	gui_input "Set new console keyboard auto-repeat rate" \
                  "$kbd_rate" "kbd_rate"
	store_kbd
}

set_kbd_delay() {
	gui_input "Set new console keyboard auto-repeat delay" \
                  "$kbd_delay" "kbd_delay"
	store_kbd
}

store_con(){
	if [ -f /etc/conf/console ] ; then
		sed -e "s/con_term=.*/con_term=$con_term/" \
		    -e "s/con_blank=.*/con_blank=$con_blank/" \
		  < /etc/conf/console > /etc/conf/console.tmp
		grep -q con_term= /etc/conf/console.tmp || \
		  echo con_term=$con_term >> /etc/conf/console.tmp
		grep -q con_blank= /etc/conf/console.tmp || \
		  echo con_blank=$con_blank >> /etc/conf/console.tmp
		mv /etc/conf/console.tmp /etc/conf/console
	else
		echo -e "con_term=$con_term\ncon_blank=$con_blank\n" \
		  > /etc/conf/console
	fi
	[ "$con_term" -a "$con_blank" ] && \
	  setterm -term $con_term -blank $con_blank > /dev/console
}

set_con_term() {
	gui_input "Set new console screen terminal type" \
                  "$con_term" "con_term"
	store_con
}

set_con_blank() {
	gui_input "Set new console screen blank interval" \
                  "$con_blank" "con_blank"
	store_con
}

set_tmzone() {
	tz="$( ls -l /etc/localtime | cut -f8 -d/ )"
	cmd="gui_menu 'general_tmzone' 'Select one of the"
	cmd="$cmd following time zones. (Current: $tz)'"

	cmd="$cmd $( grep "$1/" /usr/share/zoneinfo/zone.tab | cut -f3 | \
		cut -f2 -d/ | sort -u | tr '\n' ' ' | sed 's,[^ ]\+,& '`
		`'"ln -sf ../usr/share/zoneinfo/$1/& /etc/localtime",g' )"

	eval "$cmd"
}

set_tmarea() {
	tz="$( ls -l /etc/localtime | cut -f7 -d/ )"
	cmd="gui_menu 'general_tmarea' 'Select one of the"
	cmd="$cmd following time areas. (Current: $tz)'"

	cmd="$cmd $( grep '^[^#]' /usr/share/zoneinfo/zone.tab | cut -f3 | \
		cut -f1 -d/ | sort -u | tr '\n' ' ' | sed 's,[^ ]\+,& '`
		`'"if set_tmzone & ; then tzset=1 ; fi",g' )"

	tzset=0
	while eval "$cmd" && [ $tzset = 0 ] ; do : ; done
}

set_dtime() {
	dtime="`date '+%m-%d %H:%M %Y'`" ; newdtime="$dtime"
	[ -f /etc/conf/clock ] && . /etc/conf/clock
	[ "$clock_tz" != localtime ] && clock_tz=utc
	gui_input "Set new date and time (MM-DD hh:mm YYYY, $clock_tz)" \
	          "$dtime" "newdtime"
	if [ "$dtime" != "$newdtime" ] ; then
		echo "Setting new date and time ($newdtime) ..."
		date "$( echo $newdtime | sed 's,[^0-9],,g' )"
		hwclock --systohc --$clock_tz
	fi
}

set_locale_sub() {
	rm -f /etc/profile.d/locale
	[ "$1" != "none" ] && echo "export LANG='$1'" > /etc/profile.d/locale
}

set_locale() {
	unset LANG ; [ -f /etc/profile.d/locale ] && . /etc/profile.d/locale
	locale="${LANG:-none}" ; cmd="gui_menu 'general_locale' 'Select one of the following locales. (Current: $locale)' 'none' 'set_locale_sub none'"

	x="$( echo -e "POSIX\tC" | expand -t52 )"
	cmd="$cmd '$x' 'set_locale_sub C' $(
		grep -H ^title /usr/share/i18n/locales/* 2> /dev/null | \
		awk -F '"' '{ sub(".*/", "", $1); sub("[\\.:].*", "", $1); '"
		printf \" '%-52s%s' 'set_locale_sub %s'\", \$2, \$1, \$1; }"
	)"

	eval "$cmd"
}

main() {
    while
	unset LANG ; [ -f /etc/profile.d/locale ] && . /etc/profile.d/locale
	locale="${LANG:-none}" ; tz="$( ls -l /etc/localtime | cut -f7- -d/ )"
	keymap=$(ls -l /etc/default.keymap 2> /dev/null | sed 's,.*/,,')
	[ "$keymap" ] || keymap="none" ; keymap="${keymap%.map.gz}"
	vcfont=$(ls -l /etc/default.vcfont 2> /dev/null | sed 's,.*/,,')
	if [ -z "$vcfont" ] ; then vcfont="none"
	else vcfont="`echo $vcfont | sed -e "s,\.\(fnt\|psf.*\)\.gz$,,"`" ; fi
	dtime="`date '+%m-%d %H:%M %Y'`"
	[ -f /etc/conf/kbd ] && . /etc/conf/kbd
	[ "$kbd_rate" ] || kbd_rate=30
	[ "$kbd_delay" ] || kbd_delay=250
	[ -f /etc/conf/console ] && . /etc/conf/console
	[ "$con_term" ] || con_term=linux
	[ "$con_blank" ] || con_blank=0

	gui_menu general 'Various general system configurations' \
		"Set console keyboard mapping ....... $keymap" "set_keymap" \
		"Set console screen font ............ $vcfont" "set_vcfont" \
		"Set system-wide time zone .......... $tz"     "set_tmarea" \
		"Set date and time (utc/localtime) .. $dtime"  "set_dtime"  \
		"Set system-wide locale (language) .. $locale" "set_locale" \
		"Set console keyboard repeat rate ... $kbd_rate" "set_kbd_rate" \
		"Set console keyboard repeat delay .. $kbd_delay" "set_kbd_delay" \
		"Set console screen terminal type ... $con_term" "set_con_term" \
		"Set console screen blank interval .. $con_blank" "set_con_blank" \
		"Run the (daily) 'cron.run' script now" "cron.run"
    do : ; done
}

