/*
 * --- ROCK-COPYRIGHT-NOTE-BEGIN ---
 * 
 * This copyright note is auto-generated by ./scripts/Create-CopyPatch.
 * Please add additional copyright information _after_ the line containing
 * the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
 * the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
 * 
 * ROCK Linux: rock-src/target/livecd/linuxrc.c
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
 * linuxrc.c is Copyright (C) 2003, 2004 Cliford Wolf and Rene Rebe
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
#include <sys/utsname.h>
#include <dirent.h>
#include <fcntl.h>
#include <errno.h>
#include <stdarg.h>
#include <sys/ioctl.h>
/* this is actually a file included in dietlibc! */
#include <linux/loop.h>

#ifndef STAGE_2_IMAGE
#  define STAGE_2_IMAGE "2nd_stage.img.z"
#endif

#define DEBUG(F...) debug(__LINE__,F)

char mod_loader[50];
char mod_dir[255];
char mod_suffix[3];
int  mod_suffix_len=0;
int  do_debug=0;
char init2[32] = "/sbin/init";

void debug(int line, const char* format, ...) 
{
	if(do_debug == 0) return;

        va_list ap;
        char string[128];

        va_start(ap, format);
        vsnprintf(string, sizeof(string), format, ap);
	fprintf(stderr,"%i: %s\n", line, string);
        va_end(ap);

        return;
}

void mod_load_info(char *mod_loader, char *mod_dir, char *mod_suffix) 
{
	struct utsname uts_name;

	if(uname(&uts_name) < 0) {
		perror("unable to perform uname syscall correctly");
		return;
	} else if(strcmp(uts_name.sysname, "Linux") != 0) {
		printf("Your operating system is not supported ?!\n");
		return;
	}

	strcpy(mod_loader, "/bin/insmod");
	strcpy(mod_dir, "/lib/modules/");
	strcat(mod_dir, uts_name.release);

	/* kernel module suffix for <= 2.4 is .o, .ko if above */
	if(uts_name.release[2] > '4') {
		strcpy(mod_suffix, ".ko");
	} else {
		strcpy(mod_suffix, ".o");
	}

	return;
}

int loop_mount(const char *device, const char* file) 
{
	DEBUG("loop mounting %s on %s", device, file);
	struct loop_info loopinfo;
	int fd, ffd;
	
	if ((ffd = open(file, O_RDONLY)) < 0) {
		perror(file);
		return 1;
	}
	if ((fd = open(device, O_RDONLY)) < 0) {
		perror(device);
		return 1;
	}
	
	memset(&loopinfo, 0, sizeof(loopinfo));
	snprintf(loopinfo.lo_name, LO_NAME_SIZE, "%s", file);

	loopinfo.lo_offset = 0;
	loopinfo.lo_encrypt_key_size = 0;
	loopinfo.lo_encrypt_type = LO_CRYPT_NONE;

	if (ioctl(fd, LOOP_SET_FD, ffd) < 0) {
		perror("ioctl: LOOP_SET_FD");
		return 1;
	}
	close(ffd);
	
	if(ioctl(fd, LOOP_SET_STATUS, &loopinfo) < 0) {
		perror("ioctl: LOOP_SET_STATUS");
		(void) ioctl(fd, LOOP_CLR_FD, 0);
		close(fd);
		return 1;
	}
	close(fd);
	
	DEBUG("loop mount worked like a charm.");
	return 0;
}

void doboot()
{
	DEBUG("doboot starting - trying to exec %s",init2);
	if ( access(init2, R_OK) ) { perror("Can't access 2nd stage init"); }
	else {
		/* i get 'bad address' if i don't wait a bit here... */
		sleep(1);
		execlp(init2,init2,NULL);
		perror("execlp init2 failed");
	}
	DEBUG("doboot returning - oops!");
}

int trymount (const char* source, const char* target)
{
	DEBUG("trying to mount %s on %s...", source, target);
	if(mount(source, target, "iso9660", MS_RDONLY, NULL) != 0) {
		DEBUG("try failed");
		return 1;
	} 
	DEBUG("mount succeeded.");
	return 0;
}

void trywait(pid)
{
	if (pid < 0) perror("fork");
	else waitpid(pid, NULL, 0);
}

/* check wether a file is a directory */
int is_dir(const struct dirent *entry) 
{
	struct stat tmpstat;
	lstat(entry->d_name, &tmpstat);
	return S_ISDIR(tmpstat.st_mode);
}

/* this is used in the module loading system for sorting dirs before files */
int dirs_first_sort(const struct dirent **a, const struct dirent **b) 
{
	if(is_dir(*a)) {
		if(is_dir(*b)) return 0;
		else return 1;
	} else if(is_dir(*b)) {
		return -1;
	} else return 0;
}

/* this is used in the rm -r implementation */
int no_dot_dirs_filter(const struct dirent *entry) 
{
	if( is_dir(entry) && (!strcmp(entry->d_name,".") || !strcmp(entry->d_name,"..")) )  return 0;
	else return 1;
}


/* my own rm -r implementation - :P */
int rm_recursive(char* directory) 
{
	struct dirent **namelist;
	char oldcwd[256];
	int n, ret=0;

	getcwd(oldcwd, 256);
        if(chdir(directory)) {
                perror("chdir");
                exit(1);
        }

	n = scandir(".", &namelist, no_dot_dirs_filter, dirs_first_sort);
	if (n < 0) {
		perror("scandir"); ret = -1;
	}

	while(n--) {
		if(is_dir(namelist[n])){
			if(rmdir(namelist[n]->d_name) != 0) {
				rm_recursive(namelist[n]->d_name);
			} 
		} else {
			if(unlink(namelist[n]->d_name) != 0) {
				perror("unable to remove file"); fflush(stdout);
				ret = -1;
			}
		}
		free(namelist[n]);
	}
	free(namelist);

	chdir(oldcwd);
	if(strcmp(directory,".") && rmdir(directory) != 0) {
		perror("could not delete just-left meant-to-be-empty directory");
		ret = -1;
	}

	return ret;
}

int getdevice(char* devstr, int devlen)
{
	char devicebase[20] = "/dev/cdroms/cdrom%d";
	char *devn[10];
	char devicefile[100];
	char filename[100];
	int tmp_nr, nr=0;

	for (tmp_nr = 0; tmp_nr < 10; ++tmp_nr) {
		snprintf(devicefile, 100, devicebase, tmp_nr);
		DEBUG("checking if %s is still a valid device", devicefile);

		if ( access (devicefile, R_OK) ) {
			DEBUG("%s first unvalid device, break search", devicefile);
			break; 
		} else {
			DEBUG("%s still valid",devicefile);
		}

		devn[nr++] = strdup (devicefile);
	}

	if (!nr) {
		DEBUG("could not find a suitable cdrom device!\n");
		return -2;
	}
	
	devn[nr] = NULL;

	snprintf(filename,100,"/mnt/cdrom/%s",STAGE_2_IMAGE);
	DEBUG("looking for %s on valid devices",STAGE_2_IMAGE);

	for (nr=0; devn[nr]; nr++) {
		if(trymount(devn[nr], "/mnt/cdrom") == 0) { 
			if( access(filename, R_OK) ) {
				DEBUG("mounted %s, but could not access %s! continuing\n", devn[nr], filename);
				if(umount("/mnt/cdrom") != 0) { perror("umount wrong cdrom failed"); break; }
				continue;
			}
			strncpy(devstr, devn[nr], devlen);
			DEBUG("found 2nd stage image on %s", devstr);
			return 0;
		}
	}
	
	printf("unable to find a device containing %s!\n", STAGE_2_IMAGE);

	return -1;
}

int prepare_root() {
	struct dirent **namelist;
	char source[256], target[256];
	int n, ret=0;

	/* we need to fix some things in /dev */
	DEBUG("preparing /dev");
	if(chdir("/dev") != 0) { perror("could not chdir to /dev!"); ret=-1; }
	unlink("fd"); /*no problem if this fails*/
	if(symlink("/proc/kcore","core") != 0) { perror("could not symlink /proc/kcore to /dev/core"); ret=-1; }
	if(symlink("/proc/self/fd","fd") != 0) { perror("could not symlink /proc/self/fd to /dev/fd"); ret=-1; }
	if(symlink("fd/0","stdin") != 0) { perror("could not symlink /dev/fd/0 to /dev/stdin"); ret=-1; }
	if(symlink("fd/1","stdout") != 0) { perror("could not symlink /dev/fd/1 to /dev/stdout"); ret=-1; }
	if(symlink("fd/2","stderr") != 0) { perror("could not symlink /dev/fd/2 to /dev/stderr"); ret=-1; }
	if(chdir("/") != 0) { perror("could not chdir to /!"); ret=-1; }

	/* now create symlinks to the ro dir in the ramdisk */
	chdir("/mnt/cowfs_ro");
	n = scandir(".", &namelist, no_dot_dirs_filter, NULL);
	if (n < 0) {
		perror("scandir"); ret = -1;
	}

	while(n--) {
		snprintf(source, 256, "/mnt/cowfs_ro/%s",namelist[n]->d_name);
		snprintf(target, 256, "/mnt/cowfs_rw/%s",namelist[n]->d_name);

		if (symlink(source, target) != 0) {
			printf("error in symlinking %s -> %s\n",source,target);
			ret = -1;
		} 
		free(namelist[n]);
	}
	free(namelist);
	chdir("/");
	
	umask(00);
	unlink("/mnt/cowfs_rw/home");
	unlink("/mnt/cowfs_rw/tmp");
	mkdir("/mnt/cowfs_rw/home",0755);
	mkdir("/mnt/cowfs_rw/tmp",0777);
	mkdir("/mnt/cowfs_rw/home/rocker",0755);
	mkdir("/mnt/cowfs_rw/home/root",0700);
	if(chown("/mnt/cowfs_rw/home/rocker",1000,100) != 0) { 
		perror("could not chown /mnt/cowfs_rw/home/rocker to rocker:users"); ret=-1; 
	}
	umask(022);

	return ret;
}

void load_ramdisk_file() {
	char text[120], devicefile[100];
	char filename[100];
	int ret = 0;
	int ro_fd;

	strcpy(filename, STAGE_2_IMAGE);
	DEBUG("set stage 2 filename to %s",filename);

	/* this is retry stuff is needed for my firewire (sbp2) cd drive ... */
	do {	
		ret = getdevice(devicefile, 100);
		if (ret == -1) {
			printf("getdevice failed: no cd with image found...\n");
			return;
		} else if (ret == -2) {
			sleep(2);
			printf("no cdrom drive found - retrying...\n");
		}
	} while( ret != 0 );
	
	snprintf(text, 120, "/mnt/cdrom/%s", filename);

	DEBUG("setting up loop device...");
	if(loop_mount("/dev/loop/0",text) != 0) {
		DEBUG("loop device setup failed ... :(");
		return;
	}

	DEBUG("saving filedescriptor of /mnt/cowfs_ro");
	ro_fd = open("/mnt/cowfs_ro",O_RDONLY); if(ro_fd < 0) { perror("open"); return; }

	chdir("/mnt/cowfs_ro");
	if(rm_recursive(".") != 0) return;

	DEBUG("mounting loop device on /mnt/cowfs_ro ... ");
	if( mount("/dev/loop/0", "/mnt/cowfs_ro", "squashfs", MS_RDONLY, NULL) ) 
		{ perror("Can't mount squashfs on /mnt/cowfs_ro!"); return; }

	DEBUG("mounting tmpfs on /mnt/cowfs_rw");	
	if ( mount("none", "/mnt/cowfs_rw", "tmpfs", 0, NULL) )
		{ perror("Can't mount /mnt/cowfs_rw"); return; }

	/* create symlinks for needed directories, create special files */
	if(prepare_root() == 0) doboot();

	return;
}	



void autoload_modules()
{
	DEBUG("autoload modules starting");
	char line[200], cmd[200], module[200];
	int fd[2], rc;
	FILE *f;
	int pid;

	if (pipe(fd) <0)
		{ perror("Can't create pipe"); return; } 

	if ( (pid = fork()) == 0 ) {
		dup2(fd[1],1); close(fd[0]); close(fd[1]);
		execlp("gawk", "gawk", "-f", "/bin/hwscan", NULL);
		printf("Can't start >>hwscan<< program with gawk!\n");
		exit(1);
	}

	close(fd[1]);
	f = fdopen(fd[0], "r");
	while ( fgets(line, 200, f) != NULL ) {
		if ( sscanf(line, "%s %s", cmd, module) < 2 ) continue;
		if ( !strcmp(cmd, "modprobe") || !strcmp(cmd, "insmod") ) {
			printf("%s %s\n", cmd, module);
			if ( (rc = fork()) == 0 ) {
				execlp(cmd, cmd, module, NULL);
				perror("Cant run modprobe/insmod");
				exit(1);
			}
			trywait(rc);
		}
	}
	fclose(f);
	trywait(pid);
}

void exec_sh()
{
	int rc;

	printf ("Quit the shell to return to the stage 1 loader!\n");
	if ( (rc = fork()) == 0 ) {
	        execl("/bin/kiss", "kiss", "-E", NULL);
		perror("kiss");
		_exit(1);
	}
	trywait(rc);
}

int main(int argc, char** argv)
{
	int args;

	if(getenv("stage2init") != NULL) 
		snprintf(init2, 31, "%s", getenv("stage2init"));

	if (argc > 1) {
		for (args=1; args<argc; args++) {
			if (strstr(argv[args],"linuxrc_debug") != NULL)
				do_debug = 1;
		}
	}

	if ( mount("devfs", "/dev", "devfs", 0, NULL) && errno != EBUSY )
		perror("Can't mount /dev");

	if ( mount("sysfs", "/sys", "sysfs", 0, NULL) && errno != EBUSY )
		perror("Can't mount /sys (not fatal)");

	if ( mount("proc", "/proc", "proc", 0, NULL) && errno != EBUSY )
		perror("Can't mount /proc");

	if ( mount("devpts", "/dev/pts", "devpts", 0, NULL) && errno != EBUSY )
		perror("Can't mount /dev/pts (not too fatal)");

	if ( mount("ramfs", "/dev/shm", "ramfs", 0, NULL) && errno != EBUSY )
		perror("Can't mount /dev/shm (not fatal)");

	/* Only print important stuff to console */
	if(do_debug == 0) 
		klogctl(8, NULL, 3);
	else
		klogctl(8, NULL, 7);

	mod_load_info(mod_loader, mod_dir, mod_suffix);
	mod_suffix_len = strlen(mod_suffix);

	autoload_modules();

	printf("\n\
     ============================================\n\
     ===   ROCK Linux 1st stage boot system   ===\n\
     ============================================\n\
\n\
The ROCK Linux live CD system boots up in two stages. You are now in\n\
the first of these two stages and if everything goes right you will not\n\
spend much time here. I will just try to load some drivers (if needed)\n\
so the 2nd stage boot system can be loaded.\n");

	DEBUG("load_ramdisk_file starting...");
	load_ramdisk_file();
	DEBUG("load_ramdisk_file returned. bad. bad bad bad :((");
	
	sleep(1);

	printf("\n\nYou are still here. that means i couldn't complete the automatic boot of\n");
	printf("stage2. Please refer to the errors reported above, you will now be dumped into a\n");
	printf("minimalistic static shell so you can have a look at what went wrong...\n");

	if(access("/bin/kiss",R_OK) == 0) execl("/bin/kiss", "/bin/kiss", NULL);

	printf("\nCan't start a shell!!\n\nPlease send a bug report with your configuration to fake@rocklinux.org\n\n");
	return 0;
}

