#!/bin/sh
#
# Script for creating a minimalistic /dev directory (needed if running a
# kernel without devfs support).
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/misc/archive/mini-makedevs.sh
# ROCK Linux is Copyright (C) 1998 - 2003 Clifford Wolf
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

mknod mem c 1 1
mknod kmem c 1 2
mknod null c 1 3
mknod port c 1 4
mknod zero c 1 5
mknod core c 1 6
mknod full c 1 7
mknod random c 1 8
mknod urandom c 1 9

mknod ram0 b 1 0
mknod ram1 b 1 1
mknod ram2 b 1 2
mknod ram3 b 1 3
mknod initrd b 1 250

mknod ptyp0 c 2 0
mknod ptyp1 c 2 1
mknod ptyp2 c 2 2
mknod ptyp3 c 2 3
mknod ptyp4 c 2 4
mknod ptyp5 c 2 5
mknod ptyp6 c 2 6
mknod ptyp7 c 2 7

mknod fd0 b 2 0
mknod fd1 b 2 1

mknod ttyp0 c 3 0
mknod ttyp1 c 3 1
mknod ttyp2 c 3 2
mknod ttyp3 c 3 3
mknod ttyp4 c 3 4
mknod ttyp5 c 3 5
mknod ttyp6 c 3 6
mknod ttyp7 c 3 7

mknod hda b 3 0
mknod hda1 b 3 1
mknod hda2 b 3 2
mknod hda3 b 3 3
mknod hda4 b 3 4
mknod hda5 b 3 5
mknod hda6 b 3 6
mknod hda7 b 3 7
mknod hda8 b 3 8

mknod hdb b 3 64
mknod hdb1 b 3 65
mknod hdb2 b 3 66
mknod hdb3 b 3 67
mknod hdb4 b 3 68
mknod hdb5 b 3 69
mknod hdb6 b 3 70
mknod hdb7 b 3 71
mknod hdb8 b 3 72

mknod tty0 c 4 0
mknod tty1 c 4 1
mknod tty2 c 4 2
mknod tty3 c 4 3
mknod tty4 c 4 4
mknod tty5 c 4 5
mknod tty6 c 4 6
mknod tty7 c 4 7

mkdir -p vc
ln -sf ../tty1 vc/1
ln -sf ../tty2 vc/2
ln -sf ../tty3 vc/3
ln -sf ../tty4 vc/4
ln -sf ../tty5 vc/5
ln -sf ../tty6 vc/6
ln -sf ../tty7 vc/7

mknod ttyS0 c 4 64
mknod ttyS1 c 4 65
mknod ttyS2 c 4 66
mknod ttyS3 c 4 67

mknod tty c 5 0
mknod console c 5 1
mknod ptmx c 5 2

mknod cua0 c 5 64
mknod cua1 c 5 65
mknod cua2 c 5 66
mknod cua3 c 5 67

mknod lp0 c 6 0
mknod lp1 c 6 0

mknod vcs c 7 0
mknod vcs1 c 7 1
mknod vcs2 c 7 2
mknod vcs3 c 7 3
mknod vcs4 c 7 4
mknod vcs5 c 7 5
mknod vcs6 c 7 6
mknod vcs7 c 7 7

mknod loop0 b 7 0
mknod loop1 b 7 1
mknod loop2 b 7 2
mknod loop3 b 7 3

mknod sda b 8 0
mknod sda1 b 8 1
mknod sda2 b 8 2
mknod sda3 b 8 3
mknod sda4 b 8 4
mknod sda5 b 8 5
mknod sda6 b 8 6
mknod sda7 b 8 7
mknod sda8 b 8 8

mknod sdb b 8 16
mknod sdb1 b 8 17
mknod sdb2 b 8 18
mknod sdb3 b 8 19
mknod sdb4 b 8 20
mknod sdb5 b 8 21
mknod sdb6 b 8 22
mknod sdb7 b 8 23
mknod sdb8 b 8 24

mknod psaux c 10 1
mknod rtc c 10 135
mknod nvram c 10 144

mknod sr0 b 11 0
mknod sr1 b 11 1

mknod sg0 c 21 0
mknod sg1 c 21 1
mknod sg2 c 21 2
mknod sg3 c 21 3

mknod fb0 c 29 0
mknod fb1 c 29 32

mkdir -p pts

rm -f fd
ln -sf /proc/kcore      core
ln -sf /proc/self/fd    fd
ln -sf fd/0             stdin
ln -sf fd/1             stdout
ln -sf fd/2             stderr
