#!/bin/sh
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/rock-debug/test_unarchived.sh
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
# List all files which are not listed in /var/adm/flists/*
#
# Output format:
# File-Name
# ...

{
  { find bin boot etc lib sbin usr var opt -type f -printf '~: %p\n'
    cat /var/adm/flists/* ; } | sort +1 |
  awk 'BEGIN { last=""; } $1=="~:" && last!=$2 { print $2; } { last=$2; }'

  ls | egrep -vx 'dev|home|lost\+found|mnt|proc|root|sys|tmp' |
  egrep -vx 'bin|boot|etc|lib|sbin|usr|var|opt'
} |
egrep -xv 'etc/ld.so.cache|usr/share/info/dir|lib/modules/.*/modules.dep'

exit 0
