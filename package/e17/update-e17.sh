#!/bin/sh

echo "Updating packages in the e17 repository to version date $(date +%Y-%m-%d)"

for pkg in $(cd package/e17; echo *); do
    if [ -x "package/e17/$pkg" ]; then
	./scripts/Create-PkgUpdPatch $pkg-$(date +%Y-%m-%d) | patch -p0
    fi
done

echo "Updated done."
