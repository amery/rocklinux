#!/usr/bin/perl -w
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/base/oprofile/pulpstoner.pl
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

use English;
use strict;

my $min_samples = 1000;
my $min_percent = 2;
my $min_points = 10;

my %roots;

my %percents;
my %files;
my %binaries;
my $bin;

sub read_pkgdb($) {
	my $root=$_[0];
	print "Reading package DB from /$root ...\n";
	open(F, "cat /${root}var/adm/flists/*|") || die $!;
	while (<F>) {
		chomp; @_ = split /:\s+/;
		$files{${root}.$_[1]} = $_[0];
	}
	close F;
}
read_pkgdb("");

my $pc = 0;
open(F, "opreport -f -n | sort -r -g -k 2|") || die $!;
for (<F>) {
	@_ = split /\s+/; $pc+=$_[2];
	last if $_[1] < $min_samples;
	last if $pc > 100-$min_percent;
	next unless -f $_[3];
	$_[3] =~ s,^/,,;
	$binaries{$_[3]} = $_[2];
}
close F;

foreach $bin (keys %binaries) {
	if ( $bin =~ m,(.*/root/), and not defined $roots{$1} ) {
		$roots{$1} = 1;
		read_pkgdb($1);
	}
	if ( not defined $files{$bin} ) {
		print "Not found in package db: $bin\n";
		next;
	}
	open(F, "opreport -g --symbols -n /$bin|") || die $!;
	while (<F>) {
		next if /\(no location information\)/;
		my ($count, $percent, $src, $sym) = split /\s+/; $src =~ s/:.*//;
		$percents{sprintf "%-14s\t%-22s\t%s",
			$files{$bin}, $src, $bin} += $percent * $binaries{$bin};
	}
	close F;
}

foreach (keys %percents) {
	next if $percents{$_} < $min_points;
	printf "** %9.2f:\t%s\n", $percents{$_}, $_;
}

