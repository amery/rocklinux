#!/bin/perl
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/scripts/parasim2.pl
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

use strict;
use English;

my $logdir = $ARGV[0];
my $config = $ARGV[1];
my $id = $ARGV[2];

my $freejobs = $id;
my $runningjobs = 0;
my $now = 0;

my %jobs;
my $qid;

system("mkdir -p $logdir/logs_$id");

open(LOG, "> $logdir/parasim_$id.log") || die $!;
open(DAT, "> $logdir/parasim_$id.new") || die $!;

$|=1; print "Running simulation for $id parallel jobs ...";

while (1) {
	printf LOG "%10d: %d jobs currently running (%d idle)\n",
	           $now, $runningjobs, $freejobs;
	printf DAT "%f\t$runningjobs\t%s\n",
	           $now / 360000, join(" ", keys %jobs);
	print ".";

	foreach $qid (keys %jobs) {
		next if $jobs{$qid} > $now;
		printf LOG "%10d: Finished job $qid.\n", $now;
		system("rm -f $logdir/logs_$id/$qid.* ; " .
		       "touch $logdir/logs_$id/$qid.log");
		$freejobs++; $runningjobs--; delete $jobs{$qid};
	}

	open(Q, "./scripts/Create-PkgQueue -cfg $config " .
	        "-logdir $logdir/logs_$id | sort -r -n -k2 |") || die $!;
	while ($_=<Q> and $freejobs > 0) { 
		@_ = split /\s+/; $qid="$_[0]-$_[5]";
		s/^.*\s(\S+)\s*$/$1/; $_++;
		printf LOG "%10d: Creating new job $qid " .
		           "(pri $_[1], tm $_).\n", $now;
		system("rm -f $logdir/logs_$id/$qid.* ; " .
		       "touch $logdir/logs_$id/$qid.out");
		$jobs{$qid} = $now + $_;
		$freejobs--; $runningjobs++;
	}
	close(Q);

	$_=-1;
	foreach $qid (keys %jobs) {
		$_=$jobs{$qid} if $_ == -1 or $_ > $jobs{$qid};
	}
	if ($_ == -1) { last; } else { $now=$_; }
}

printf DAT "%f\t0\n", $now / 360000;
print "\nSimulated build for $id parallel jobs finished.\n\n";

close LOG; close DAT;
system("mv $logdir/parasim_$id.new $logdir/parasim_$id.dat");
