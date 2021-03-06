# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/avm/bootsplash/stone_mod_bootsplash.sh
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
#
# [MAIN] 80 bootsplash BOOTSPLASH theme activation

SPLASH="/sbin/splash"
INITRD="/boot/initrd.img"

select_theme(){
    cmd="gui_menu 'select_theme' 'Select one of the following theme'"
    cmd="$cmd $( find /etc/bootsplash/themes/*/config -type d | \
         sed -re 's,^.*/themes/(.*)/config.*$,"\1" "BOOTSPLASH_THEME=\1",' | \
         sort | tr '\n' ' ')"

    eval "$cmd"
    write_bsconfig
}

select_cfgfile(){
    cmd="gui_menu 'select_cfgfile'"
    cmd="$cmd 'Select one of the config file for the $BOOTSPLASH_THEME theme'"
    cmd="$cmd $( find /etc/bootsplash/themes/$BOOTSPLASH_THEME/config -type f| \
         sed -re 's,^.*config/(.*),"\1" "BOOTSPLASH_CFGFILE=\"\1\"",' | sort | tr '\n' ' ')"

    eval "$cmd"
    write_bsconfig
}

write_bsconfig(){
    cat << EOC > /etc/bootsplash/config
BOOTSPLASH_THEME="$BOOTSPLASH_THEME" 
BOOTSPLASH_CFGFILE="$BOOTSPLASH_CFGFILE"
EOC
}

main() {
    while
        BOOTSPLASH_THEME="Linux"
        BOOTSPLASH_CFGFILE="bootsplash-1024x768.cfg"
        if [ -f /etc/bootsplash/config ]; then
            . /etc/bootsplash/config
        fi
        gui_menu bootsplash 'Bootsplash Setup' \
            "Bootsplash Theme ......... $BOOTSPLASH_THEME" 'select_theme' \
            "Bootsplash Config File ... $BOOTSPLASH_CFGFILE" 'select_cfgfile' \
            "" "" \
            'Append Bootsplash Image to initrd' \
                'gui_cmd "Appending Bootsplash Image 1024x68 to initrd" \
                "$SPLASH -s -f /etc/bootsplash/themes/$BOOTSPLASH_THEME/config/$BOOTSPLASH_CFGFILE >> $INITRD"'
    do : ; done
}

