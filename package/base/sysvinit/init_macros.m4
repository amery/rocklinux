dnl
dnl Macros for creating the SysV init scripts with nice or raw output
dnl
dnl --- ROCK-COPYRIGHT-NOTE-BEGIN --- 
dnl 
dnl This copyright note is auto-generated by ./scripts/Create-CopyPatch.
dnl Please add additional copyright information _after_ the line containing
dnl the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
dnl the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
dnl 
dnl ROCK Linux: rock-src/package/base/sysvinit/init_macros.m4
dnl ROCK Linux is Copyright (C) 1998 - 2006 Clifford Wolf
dnl 
dnl This program is free software; you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published by
dnl the Free Software Foundation; either version 2 of the License, or
dnl (at your option) any later version. A copy of the GNU General Public
dnl License can be found at Documentation/COPYING.
dnl 
dnl Many people helped and are helping developing ROCK Linux. Please
dnl have a look at http://www.rocklinux.org/ and the Documentation/TEAM
dnl file for details.
dnl 
dnl --- ROCK-COPYRIGHT-NOTE-END ---
dnl
divert(-1)

initstyle = sysv_nice ....... Nice colored output
initstyle = sysv_text ....... Raw text output

ifelse(initstyle, `sysv_nice',
	`define(`IT', `dnl')
	define(`IN', `')'
,
	`define(`IT', `')
	define(`IN', `dnl')'
)

define(`this_is_not_the_first_option', `')
define(`default_restart', `    restart)
	`$'0 stop; `$'0 start
	;;

')

define(`end_restart', ` | restart')

ifelse(initstyle, `sysv_nice', `
	define(`main_begin', `title() {
	local x w="`$'( stty size 2>/dev/null </dev/tty | cut -d" " -f2  )"
	[ -z "`$'w" ] && w="`$'( stty size </dev/console | cut -d" " -f2  )"
	for (( x=1; x<w; x++ )) do echo -n .; done
	echo -e "\e[222G\e[3D v \r\e[36m`$'* \e[0m"
	error=0
}

status() {
	if [ `$'error -eq 0 ]
	then
		echo -e "\e[1A\e[222G\e[4D\e[32m :-)\e[0m"
	else
		echo -e "\e[1A\e[222G\e[4D\a\e[1;31m :-(\e[0m"
	fi
}

case "`$'1" in')
' , `
	define(`main_begin', `case "`$'1" in')
')
define(`main_end', `default_restart    *)
	echo "Usage: `$'0 { undivert(1)end_restart }"
	exit 1 ;;

esac

exit 0')

ifelse(initstyle, `sysv_nice', `

	define(`echo_title', `ifelse(`$1', `', `define(`dostatus', 0)dnl', `define(`dostatus', 1)	title "$1"')')

	define(`echo_status', `ifelse(dostatus, 1, `	status', `dnl')')

	define(`check', `ifelse(dostatus, 1, `$* || error=$?', `$*')')

' , `

	define(`echo_title', `ifelse(`$1', `', `dnl', `	echo "$1"')')
	define(`echo_status', `dnl')
	define(`check', `$*')
')

define(`block_begin', `$1)
divert(1)dnl
this_is_not_the_first_option`$1'dnl
define(`this_is_not_the_first_option',` | ')dnl
define(`default_$1', `')dnl
define(`end_$1', `')dnl
divert(0)dnl
echo_title(`$2')')

define(`block_split', `echo_status

echo_title(`$1')')

define(`block_end', `echo_status
	;;')

divert(0)dnl
