/*
 * --- ROCK-COPYRIGHT-NOTE-BEGIN ---
 * 
 * This copyright note is auto-generated by ./scripts/Create-CopyPatch.
 * Please add additional copyright information _after_ the line containing
 * the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
 * the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
 * 
 * ROCK Linux: rock-src/misc/tools-source/fl_stparse.c
 * ROCK Linux is Copyright (C) 1998 - 2004 Clifford Wolf
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

#define _GNU_SOURCE

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#define MAXPROCS 512

struct procs_t {
	int pid;
	char * cwd;
} procs[MAXPROCS];

void newproc(int pid, char * cwd) {
	int c;
	for (c=0; c<MAXPROCS; c++)
		if (procs[c].pid == 0) {
			procs[c].pid = pid;
			procs[c].cwd = cwd;
			return;
		}

	fprintf(stderr, "fl_stparse: No more free procs in list!\n");
	exit(1);
}

struct procs_t * getproc(int pid) {
	int c;
	for (c=0; c<MAXPROCS; c++)
		if (procs[c].pid == pid) {
			return procs + c;
		}

	fprintf(stderr, "fl_stparse: Can't find proc %d!\n", pid);
	exit(1);
}

void setproc(int pid, char * cwd) {
	int c;
	for (c=0; c<MAXPROCS; c++)
		if (procs[c].pid == pid) {
			free(procs[c].cwd);
			procs[c].cwd = cwd;
			return;
		}

	fprintf(stderr, "fl_stparse: Can't set proc %d!\n", pid);
	exit(1);
}

void freeproc(int pid) {
	int c;
	for (c=0; c<MAXPROCS; c++)
		if (procs[c].pid == pid) {
			procs[c].pid=0;
			free(procs[c].cwd);
			procs[c].cwd=NULL;
			return;
		}

	fprintf(stderr, "fl_stparse: Can't free proc %d!\n", pid);
	exit(1);
}

int main(int argc, char ** argv) {
	char line[1024];
	char buf1[1024];
	char buf2[1024];
	int pid, newpid;
	char *sp1, *sp2;

	FILE *wlog = fopen("/dev/null", "w");
	FILE *rlog = fopen("/dev/null", "w");
	FILE *logfile;
	int opt;

	while ( (opt = getopt(argc, argv, "w:r:")) != -1 ) {
		switch (opt) {
		    case 'w':
			fclose(wlog);
			wlog = fopen(optarg, "w");
			break;

		    case 'r':
			fclose(rlog);
			rlog = fopen(optarg, "w");
			break;

		    default:
			fprintf(stderr, "Usage: %s [-w wlog-file] "
			                "[-r rlog-file]\n", argv[0]);
			return 1;
		}
	}

	if (fgets(line, 1024, stdin) &&
	    sscanf(line, "%d", &pid) == 1 ) {
		newproc(pid, getcwd((char *) NULL, 0) );
	} else {
		fprintf(stderr, "fl_stparse: Can't init using first line "
		                "of input!\n");
		return 1;
	}

	do {
		// ignore this line if syscall returned error
		if ( strstr(line, " = -1 E") ) continue;
		if ( sscanf(line, "%d fork() = %d", &pid, &newpid) == 2 ||
		     sscanf(line, "%d clone(%[^)]) = %d", &pid, buf1,
                                                        &newpid) == 3 ||
		     sscanf(line, "%d vfork() = %d", &pid, &newpid) == 2 ||
		     sscanf(line, "%d <... fork resumed> ) = %d",
							&pid, &newpid) == 2 ||
		     sscanf(line, "%d <... clone resumed> %[^)]) = %d",
                                                        &pid, buf1,
                                                        &newpid) == 3 ||
		     sscanf(line, "%d <... clone resumed> ) = %d",
							&pid, &newpid) == 2 ||
		     sscanf(line, "%d <... vfork resumed> ) = %d",
							&pid, &newpid) == 2) {
			sp1 = getproc(pid)->cwd;
			sp2 = malloc( strlen(sp1) + 1);
			strcpy(sp2, sp1);
			newproc(newpid, sp2 );
			continue;
		}

		if ( sscanf(line, "%d _exit(%d", &pid, &newpid) == 2 ||
	             sscanf(line, "%d exit(%d", &pid, &newpid) == 2 ||
		     sscanf(line, "%d exit_group(%d", &pid, &newpid) == 2 ) {
			freeproc(pid);
			continue;
		}

		if ( sscanf(line, "%d chdir(\"%[^\"]", &pid, buf1) == 2 ) {
			chdir( getproc(pid)->cwd ); chdir( buf1 );
			setproc(pid, getcwd((char *) NULL, 0) );
			continue;
		}

		if ( sscanf(line, "%d open(\"%[^\"]\", %s",
						&pid, buf1, buf2) == 3 ) {
			if (strstr(buf2, "O_RDONLY") == NULL) logfile = wlog;
			else logfile = rlog;

			if (strstr(buf2, "O_DIRECTORY") != NULL) continue;

			if (buf1[0] == '/') {
				fprintf(logfile, "%d: %s\n", pid, buf1);
			} else {
				sp1 = getproc(pid)->cwd;
				if (!strcmp(sp1, "/")) sp1="";
				fprintf(logfile, "%d: %s/%s\n",
				                 pid, sp1, buf1);
			}
			continue;
		}

		if ( sscanf(line, "%d mkdir(\"%[^\"]\", ", &pid, buf1) == 2 ||
		     sscanf(line, "%d utime(\"%[^\"]\", ", &pid, buf1) == 2 ||
		     sscanf(line, "%d link(\"%[^\"]\", \"%[^\"]\"",
						&pid, buf2, buf1) == 3 ||
		     sscanf(line, "%d symlink(\"%[^\"]\", \"%[^\"]\"",
						&pid, buf2, buf1) == 3 ||
		     sscanf(line, "%d rename(\"%[^\"]\", \"%[^\"]\"",
						&pid, buf2, buf1) == 3 ) {
			if (buf1[0] == '/') {
				fprintf(wlog, "%d: %s\n", pid, buf1);
			} else {
				sp1 = getproc(pid)->cwd;
				if (!strcmp(sp1, "/")) sp1="";
				fprintf(wlog, "%d: %s/%s\n",
				              pid, sp1, buf1);
			}
			continue;
		}

	} while (fgets(line, 1024, stdin) != NULL);
	return 0;
}
