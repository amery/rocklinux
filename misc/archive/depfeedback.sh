#!/bin/bash
#
# Given are builds without stage 9 in which broken packages
# have been rebuilt unless all deps are resolved.
#
# This script is trying to resolve all cyclic deps causing
# troubles in scripts/Check-Deps-2 by looking into the dep
# files from the given builds and adding del entries to
# scripts/dep_fixes.txt for those of the cyclic deps present
# in scripts/dep_db.txt but not in the given builds deps.
#
# So you can do stuff like:
#
# while ./depfeedback.sh build/ref06* >> scripts/dep_fixes.txt; do true; done

if [ "$1" = "merge" ]
then
	shift
	perl -e '
		my %deps;

		while (<>) {
			comp; next unless s/^(\S+)\s+del\s+//;
			my $p = $1; @_ = split /\s+/;
			$deps{$p}{$_} = 1 foreach (@_);
		}

		foreach (sort keys %deps) {
			print "$_", length $_ < 8 ? "\t\t" : length $_ >= 16 ? " " : "\t";
			print "del\t", join(" ", sort keys %{$deps{$_}}), "\n"
		}
	' "$@"
	exit 0
fi

if [ -z "$1" -o ! -d "$1/var/adm/dependencies" ]
then
	echo "Usage: $0 build/<ROCKCFGID> [ ... ] >> scripts/dep_fixes.txt"
	echo "       $0 merge list1 list2 list3 ..."
	exit 1
fi

rm -f dependencies.dot dependencies.dbg
rm -f dependencies.patch dependencies.done
./scripts/Check-Deps-2 > /dev/null

if [ -f dependencies.dot ]
then
	echo -n > dependencies.done
	while read dep pkg; do
		for x; do
			if [ -f "$x/var/adm/logs/5-$pkg.log" -a \
			     -f "$x/var/adm/dependencies/$pkg" ]
			then
				if ! grep -qx "$pkg: $dep" "$x/var/adm/dependencies/$pkg"; then
					echo "$pkg del $dep" >> dependencies.done
				fi
			fi
		done
	done < dependencies.dbg

	if [ -s dependencies.done ]
	then
		bash $0 merge dependencies.done
		echo Found $(wc -l < dependencies.done) questionable deps. >&2
	else
		rm -f dependencies.dot dependencies.dbg
		rm -f dependencies.patch dependencies.done
		echo "No questionable deps found, still some cyclic deps left." >&2
		exit 1
	fi
else
	rm -f dependencies.dot dependencies.dbg
	rm -f dependencies.patch dependencies.done
	echo "No cyclic deps left." >&2
	exit 1
fi

rm -f dependencies.dot dependencies.dbg
rm -f dependencies.patch dependencies.done
exit 0

