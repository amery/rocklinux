#!/usr/bin/perl
#
# re-run this scrip if hosted_cpan.txt has changed
# generates hosted_cpan.{desc,sel,cfg}
#
# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/import/cpan/hosted_cpan.pl
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

my $cpanbase="http://www.cpan.org/modules/by-authors/id";

my %hosted;
my %flags;

open(F, "hosted_cpan.txt") || die $!;

while (<F>) {
	chomp;
	next if /^#/ or /^\s*$/;
	die unless /^(\S+)\s+(\S+)(\s+.*\S|)/;
	my ($p, $m, $f) = ($1, $2, $3);
	$f =~ s/(\S+)/flag $1/g;
	$hosted{$m} = $p;
	$flags{$m} = $f;
}

close F;

my %cksum;
if ( open(D, "<hosted_cpan.desc") ) {
	while (<D>) {
		next unless /^.D. (\d+) (\S+)/;
		$cksum{$2} = $1;
	}
	close D;
}

open(F, "bzip2 -d < ../../../download/mirror/c/cpan_packages_20041221.txt.bz2 |") || die $!;
open(D, ">hosted_cpan.desc") || die $!;
open(S, ">hosted_cpan.sel") || die $!;
open(C, ">hosted_cpan.cfg") || die $!;

print D "# Auto-generated by hosted_cpan.pl from hosted_cpan.txt\n";
print S "# Auto-generated by hosted_cpan.pl from hosted_cpan.txt\n";
print C "# Auto-generated by hosted_cpan.pl from hosted_cpan.txt\n";

print S "\ncase \"\$xpkg\" in\n";
print D "\n"; print C "\n";

while (<F>) {
	chomp;
	last if $_ =~ /^\s*$/;
}

while (<F>) {
	my ($mod, $ver, $loc) = split /\s+/;

	next unless $loc=~/(.*\/)([^\/]+)/;
	my ($d, $f) = ($1, $2);

	my $key = $mod;
	goto matched if defined $hosted{$key};

	foreach (keys %hosted) {
		$key = $_;
		goto matched if $mod =~ /^${key}::/;
	}
	next;

matched:
	my $xmod = $key;
	$xmod =~ y/A-Z/a-z/;
	$xmod =~ s/::/-/g;

	my $ymod = $key;
	$ymod =~ y/a-z/A-Z/;
	$ymod =~ s/::/_/g;

	print "$key -> $mod -> cpan-$xmod\n";

	my $cksum = defined $cksum{$f} ? $cksum{$f} : 0;

	print D "#if xpkg == cpan-$xmod\n";
	print D "[V] $ver\n";
	print D "[D] $cksum $f $cpanbase/$d\n";
	print D "#endif\n\n";

	$f =~ s/\.gz$/.bz2/;
	print S "\tcpan-$xmod)\n";
	print S "\t\tcpanmod=\"$mod\"\n";
	print S "\t\tcpanver=\"$ver\"\n";
	print S "\t\tcpanloc=\"$loc\"\n";
	print S "\t\tsrctar=\"$f\"\n";
	print S "\t\t;;\n";

	print C "pkgfork cpan cpan-$xmod status X priority $hosted{$key}$flags{$key}\n";

	delete $hosted{$key};
}

print S "esac\n\n";

close D; close S;
close F; close C;

