#! /bin/bash

if any_installed ".*\.so"; then
	echo "dynamic libraries installed, run ldconfig!"
fi

if any_removed ".*\.so"; then
	echo "dynamic libraries removed, run ldconfig!"
fi

all_installed ".*" | while read M; do echo "Installed: $M"; done
all_removed ".*" | while read M; do echo "Removed: $M"; done

