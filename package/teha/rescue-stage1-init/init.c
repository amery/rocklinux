/*
 * --- ROCK-COPYRIGHT-NOTE-BEGIN ---
 * 
 * This copyright note is auto-generated by ./scripts/Create-CopyPatch.
 * Please add additional copyright information _after_ the line containing
 * the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
 * the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
 * 
 * ROCK Linux: rock-src/package/teha/rescue-stage1-init/init.c
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
 *
 * This is stage1 init for ROCK Linux advanced rescue system (C) 2004 Tobias Hintze
 *
 * Plan:
 *  - mount boot filesystem
 *  - mount tmpfs as new root filesystem
 *  - extract system.tar.bz2 and overlay.tar.bz2 from boot filesystem into new root filesystem
 *  - move /dev under new root
 *  - do pivot_root into tmpfs
 *  - exec /sbin/init in new root
 * 
 * This init accepts the following (kernel append) parameters:
 * *_PARAM macros hold parameter names only!
 * 
 * SYSTEM_FAILURE_PARAM - action to be taken if extracting system fails
 *  (panic|reboot|shell)
 * 
 * OVERLAY_FAILURE_PARAM - action to be taken if extracting overlay fails
 *  (panic|reboot|shell|ignore)
 * 
 * SYSTEM_LOCATION_PARAM - name and path of system.tar.bz2
 *  NB: boot filesystem mounted as /mnt_boot
 * 
 * OVERLAY_LOCATION_PARAM - name and path of overlay.tar.bz2
 *  NB: boot filesystem mounted as /mnt_boot
 * 
 * BOOT_DEVICE_PARAM - device that holds boot filesystem
 *
 * STAGE2_INIT_PARAM - executable to be run in stage2
 * 
 */

#include <sys/mount.h>
#include <sys/swap.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/klog.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <linux/reboot.h>

int verbose = 0;

#define VERBOSE_PARAM "verbose"
#define SYSTEM_FAILURE_PARAM "system_failure"
#define OVERLAY_FAILURE_PARAM "overlay_failure"
#define SYSTEM_LOCATION_PARAM "system"
#define OVERLAY_LOCATION_PARAM "overlay"
#define STAGE2_INIT_PARAM "stage2init"
#define BOOT_DEVICE_PARAM "boot"

#ifndef DEFAULT_BOOT_DEVICE
#define DEFAULT_BOOT_DEVICE "/dev/discs/disc0/part1"
#endif

#ifndef DEFAULT_STAGE2_INIT
#define DEFAULT_STAGE2_INIT "/sbin/init"
#endif

#ifndef DEFAULT_BOOT_FST
#define DEFAULT_BOOT_FST "ext2"
#endif

#ifndef DEFAULT_SYSTEM_LOCATION
#define DEFAULT_SYSTEM_LOCATION "/mnt_boot/rescue/system.tar.bz2"
#endif

#ifndef DEFAULT_OVERLAY_LOCATION
#define DEFAULT_OVERLAY_LOCATION "/mnt_boot/rescue/overlay.tar.bz2"
#endif

#ifndef DEFAULT_ACTION_ON_SYSTEM_FAILURE
#define DEFAULT_ACTION_ON_SYSTEM_FAILURE "shell"
#endif

#ifndef DEFAULT_ACTION_ON_OVERLAY_FAILURE
#define DEFAULT_ACTION_ON_OVERLAY_FAILURE "ignore"
#endif

#define PANIC  1
#define REBOOT 2
#define SHELL  3
#define IGNORE 4

#ifndef MS_MOVE
#  define MS_MOVE	8192
#endif

/* 64 MB should be enough for the tmpfs */
#define TMPFS_OPTIONS "size=67108864"

extern char **environ;

static int system_failure;
static int overlay_failure;

int pivot_root(const char *new_root, const char *put_old);

int untarbz2(const char *arch, const char *trg_dir) {
	int status;

	if (!fork()) {
#ifdef VEROSE
		printf("Extracting %s ...", arch); fflush(stdout);
#endif
		execlp("tar", "tar", "--use-compress-program=bzip2", "-C", trg_dir, "-xf", arch, NULL);
		perror("tar");
		_exit(1);
	}
	wait(&status);

#ifdef VEROSE
	printf(" finished (%i).\n\n", status);
#endif
	return WEXITSTATUS(status);
}

void die() {
	printf("Aieee. I lost all hope. Take that shell!\n\n");
	execl("/bin/sh", "sh", 0);
	perror("sh");
	_exit(1);
}

void shell() {
	printf("Quit the shell to continue in stage 1 loader!\n");
	if (!fork()) {
		execl("/bin/sh", "sh", 0);
		perror("sh");
		_exit(1);
	}
	wait(0);
}

void do_reboot() {
	reboot(LINUX_REBOOT_CMD_RESTART);
}

void raise_panic() {
	if (verbose) {
		printf("Terminating process to trigger kernel panic...\n\n");
	}
	_exit(0);
}


int main(int argc, char **argv) {
	int i, err;	
	char *syst = DEFAULT_SYSTEM_LOCATION;
	char *overlay = DEFAULT_OVERLAY_LOCATION;
	char *bootdev = DEFAULT_BOOT_DEVICE;
	char *bootfst = DEFAULT_BOOT_FST;
	char *stage2init = DEFAULT_STAGE2_INIT;

	/* pre read environment; determine verbosity */
	for (i=0; ; i++) {
		if (!environ[i]) break;
		if (!i) continue;
		if (!strcmp(VERBOSE_PARAM, environ[i])) verbose = 1;
		if (!strcmp(VERBOSE_PARAM "=1", environ[i])) verbose = 1;
		if (!strcmp(VERBOSE_PARAM "=yes", environ[i])) verbose = 1;
		if (!strcmp(VERBOSE_PARAM "=on", environ[i])) verbose = 1;
	}

	if (verbose) {
		printf("\n"
			"=========================================\n"
			"===   ROCK Linux rescue boot system   ===\n"
			"===        rescue-stage1-init         ===\n"
			"=========================================\n"
			"(verbose operation)"
			"\n\n");
	}

	/* evaluate compile-time defaults */
	if (!strcmp(DEFAULT_ACTION_ON_SYSTEM_FAILURE, "reboot")) system_failure = REBOOT;
	if (!strcmp(DEFAULT_ACTION_ON_SYSTEM_FAILURE, "panic"))  system_failure = PANIC;
	if (!strcmp(DEFAULT_ACTION_ON_SYSTEM_FAILURE, "shell"))  system_failure = SHELL;

	if (!strcmp(DEFAULT_ACTION_ON_OVERLAY_FAILURE, "panic"))  overlay_failure = PANIC;
	if (!strcmp(DEFAULT_ACTION_ON_OVERLAY_FAILURE, "reboot")) overlay_failure = REBOOT;
	if (!strcmp(DEFAULT_ACTION_ON_OVERLAY_FAILURE, "shell"))  overlay_failure = SHELL;
	if (!strcmp(DEFAULT_ACTION_ON_OVERLAY_FAILURE, "ignore")) overlay_failure = IGNORE;


	for (i=0; ; i++) {
		if (!environ[i]) break;
		if (verbose) {
			printf("environ[%i]: %s\n", i, environ[i]);
		}
		if (!i) continue;
		/* read failure behaviour from parameter */
		if (!strcmp(SYSTEM_FAILURE_PARAM "=reboot", environ[i])) system_failure = REBOOT;
		if (!strcmp(SYSTEM_FAILURE_PARAM "=panic", environ[i])) system_failure = PANIC;
		if (!strcmp(SYSTEM_FAILURE_PARAM "=shell", environ[i])) system_failure = SHELL;
		if (!strcmp(OVERLAY_FAILURE_PARAM "=reboot", environ[i])) overlay_failure = REBOOT;
		if (!strcmp(OVERLAY_FAILURE_PARAM "=panic", environ[i])) overlay_failure = PANIC;
		if (!strcmp(OVERLAY_FAILURE_PARAM "=shell", environ[i])) overlay_failure = SHELL;
		if (!strcmp(OVERLAY_FAILURE_PARAM "=ignore", environ[i])) overlay_failure = IGNORE;

		/* path to system.tar.bz2 as parameter? */
		if (!strncmp(SYSTEM_LOCATION_PARAM "=", environ[i], strlen(SYSTEM_LOCATION_PARAM "="))) {
			syst = environ[i] + strlen(SYSTEM_LOCATION_PARAM "=");
		}

		/* path to overlay.tar.bz2 as parameter? */
		if (!strncmp(OVERLAY_LOCATION_PARAM "=", environ[i], strlen(OVERLAY_LOCATION_PARAM "="))) {
			overlay = environ[i] + strlen(OVERLAY_LOCATION_PARAM "=");
		}

		/* stage2 init as parameter? */
		if (!strncmp(STAGE2_INIT_PARAM "=", environ[i], strlen(STAGE2_INIT_PARAM "="))) {
			stage2init = environ[i] + strlen(STAGE2_INIT_PARAM "=");
		}

		/* boot device */
		if (!strncmp(BOOT_DEVICE_PARAM "=", environ[i], strlen(BOOT_DEVICE_PARAM "="))) {
			char *p;
			bootdev = environ[i] + strlen(BOOT_DEVICE_PARAM "=");
			/* check for specified boot-fstype */
			if (p = strchr((const char*)bootdev, (int)':')) {
				bootfst = bootdev;
				bootdev = p+1;
				*p = 0;
			}
		}
	 }

	if (mount("devfs", "/dev", "devfs", 0, NULL)) {
		if (errno != EBUSY) { /* might be mounted automatically at boot */
			perror("Can't mount /dev");
			die();
		}
	}
	
	if (mount(bootdev, "/mnt_boot", bootfst, MS_RDONLY, 0)) {
		perror("Can't mount boot device. I need it at /mnt_boot - good luck.");
		printf("I tried: mount(%s, /mnt_boot, %s, MS_RDONLY, 0)\n",
			bootdev, bootfst);
		shell();
	}
	if (mount("tmpfs", "/mnt_root", "tmpfs", 0, TMPFS_OPTIONS)) {
		perror("Can't mount root-tmpfs. I need it at /mnt_root - good luck.");
		shell();
	}
	
	err = 0;
	if (!access(syst, R_OK)) {
		if (verbose) {
			printf("Found %s. Using as system.\n", syst);
		}
		if (untarbz2((const char*)syst, "/mnt_root")) {
			printf("Failed to extract rescue system. ");
			err = 1;
		}
	} else {
		printf("System %s not found! ", syst);
		err = 1;
	}
	if (err) {
		switch (system_failure) {
			case SHELL:
				printf("Spawning shell.\n", syst);
				shell();
				break;
			case REBOOT:
				printf("Going to reboot.\n", syst);
				do_reboot();
				break;
			case PANIC:
				printf("Going to panic kernel.\n", syst);
				raise_panic();
				break;
		}
	}

	err = 0;
	if (!access(overlay, R_OK)) {
		if (verbose) {
			printf("Found %s. Using as overlay.\n", overlay);
		}
		if (untarbz2((const char*)overlay, "/mnt_root")) {
			printf("Failed to extract system overlay. ");
			err = 1;
		}
	} else {
		printf("Overlay %s not found! ", overlay);
		err = 1;
	}
	if (err) {
		switch (overlay_failure) {
			case SHELL:
				printf("Spawning shell.\n", syst);
				shell();
				break;
			case REBOOT:
				printf("Going to reboot.\n", syst);
				do_reboot();
				break;
			case PANIC:
				printf("Going to panic kernel.\n", syst);
				raise_panic();
				break;
			case IGNORE:
				if (verbose) {
					printf("Ignoring.\n", overlay);
				}
				break;
		}
	}

	if (mkdir("/mnt_root/old_root", 700)) {
		perror("Can't mkdir mount point for old root.");
		die();
	}
	if (pivot_root("/mnt_root", "/mnt_root/old_root")) {
		perror("Can't pivot_root()");
		die();
	}

	chdir("/");
	if (mount("/old_root/dev", "/dev", NULL, MS_MOVE, NULL))
		perror("Can't remount /old_root/dev as /dev");

	/* if (mount("/old_root/proc", "/proc", NULL, MS_MOVE, NULL))
		perror("Can't remount /old_root/proc as /proc"); */

	execl(stage2init, stage2init, 0);
	printf("\n\nAieeee. Failed to execute stage2 init (%s).\n\n", stage2init);
	sleep(1);
	execl("/bin/sh", "/bin/sh", 0);
	printf("\n\nAieeee. Failed to execute stage2 shell (fallback).\n\n");
	sleep(10);

	return 0;
}
