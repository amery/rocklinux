/*
 * --- ROCK-COPYRIGHT-NOTE-BEGIN ---
 * 
 * This copyright note is auto-generated by ./scripts/Create-CopyPatch.
 * Please add additional copyright information _after_ the line containing
 * the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
 * the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
 * 
 * ROCK Linux: rock-src/misc/tools-source/getfiles.c
 * ROCK Linux is Copyright (C) 1998 - 2005 Clifford Wolf
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version. A copy of the GNU General Public
 * License can be found at Documentation/COPYING.
 * 
 * Many people helped and are helping developing ROCK Linux. Please
 * have a look at http://www.rocklinux.org/ and the Documentation/TEAM
 * file for details.
 * 
 * --- ROCK-COPYRIGHT-NOTE-END ---
 */

#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

int main(int argc, char ** argv) {
	char *fn, buf[512], *n;
	struct stat st;
	if (argc > 1) chdir(argv[1]);
	while ( fgets(buf, 512, stdin) != NULL &&
					(fn = strchr(buf, ' ')) != NULL ) {
		if ( (n = strchr(++fn, '\n')) != NULL ) *n = '\0';
		if ( !stat(fn,&st) && S_ISREG(st.st_mode) )
			puts(fn);
	}
	return 0;
}
