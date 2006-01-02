#!/usr/bin/perl -w
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/misc/archive/split-patch.pl
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

use strict;
use English;

open(F,">/dev/null") || die $!;

while (<>) {
	next if /^diff /;
	if (/^--- (\S+)\s/) {
		my $fn=$1; $fn=~s,/,:,g;
		$fn=~s,^[^:]+:,,; $fn.=".patch";
		print "Writing $fn ...\n";
		close(F); open(F,">$fn") || die $!;
	}
	print F;
}

close(F);
