# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/at/subs.sed
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

s@_MAN_DIR@/usr/man@g
s@_GID_STRING@daemon@g
s@_ATSPOOL_DIR@/var/spool/atspool@g
s@_ATLIB_DIR@/usr/lib@g
s@_ATJOB_DIR@/var/spool/atjobs@g
s@_DEBUG@@g
s@_SYMB@-s@g
s@_DEFAULT_BATCH_QUEUE@E@g
s@_DEFAULT_AT_QUEUE@c@g
s@_PROC_DIR@/proc@g
s@_BIN_DIR@/usr/bin@g
s@_UID_STRING@daemon@g
s@_LOADAVG_MX@1.5@g
s@_PERM_PATH@/etc@g
s@_MAIL_CMD@/usr/sbin/sendmail@g
s@_DAEMON_GID@2@g
s@_DAEMON_UID@2@g
