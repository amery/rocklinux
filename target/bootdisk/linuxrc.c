
/*
 * --- ROCK-COPYRIGHT-NOTE-BEGIN ---
 * 
 * This copyright note is auto-generated by ./scripts/Create-CopyPatch.
 * Please add additional copyright information _after_ the line containing
 * the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
 * the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
 * 
 * ROCK Linux: rock-src/target/bootdisk/linuxrc.c
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
#include "libcheckisomd5.h"

#ifndef MS_MOVE
#  define MS_MOVE	8192
#endif

#ifndef STAGE_2_BIG_IMAGE
#  define STAGE_2_BIG_IMAGE "2nd_stage.tar.gz"
#endif

#ifndef STAGE_2_SMALL_IMAGE
#  define STAGE_2_SMALL_IMAGE "2nd_stage_small.tar.gz"
#endif

#ifndef STAGE_2_COMPRESS_ARG
#  define STAGE_2_COMPRESS_ARG "--use-compress-program=gzip"
#endif

/* 640kB, err, 64 MB should be enought for the tmpfs ;-) */
#define TMPFS_OPTIONS "size=67108864"

/* It seams like we need this prototype here ... */
int pivot_root(const char *new_root, const char *put_old);

int exit_linuxrc=0;

char mod_loader[50];
char mod_dir[255];
char mod_suffix[3];
int  mod_suffix_len=0;

void mod_load_info(char *mod_loader, char *mod_dir, char *mod_suffix) {
	struct utsname uts_name;

	if(uname(&uts_name) < 0) {
		perror("unable to perform uname syscall correctly");
		return;
	} else if(strcmp(uts_name.sysname, "Linux") != 0) {
		printf("Your operating system is not supported ?!\n");
		return;
	}

	strcpy(mod_loader, "/sbin/insmod");
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

void doboot()
{
	if ( mkdir("/mnt_root/old_root", 700) )
		{ perror("Can't create /mnt_root/old_root"); exit_linuxrc=0; }

	if ( access("/mnt_root/linuxrc", R_OK) )
		{ printf("Can't find /mnt_root/linuxrc!\n"); exit_linuxrc=0; }

	if ( exit_linuxrc ) {
		if ( pivot_root("/mnt_root", "/mnt_root/old_root") )
			{ perror("Can't call pivot_root"); exit_linuxrc=0; }
		chdir("/");

		if ( mount("/old_root/dev", "/dev", "", MS_MOVE, NULL) )
			perror("Can't remount /old_root/dev as /dev");

		if ( mount("/old_root/proc", "/proc", "", MS_MOVE, NULL) )
			perror("Can't remount /old_root/proc as /proc");
	} else {
		if ( rmdir("/mnt_root/old_root") )
			perror("Can't remove /mnt_root/old_root");

		if ( umount("/mnt_root") ) perror("Can't umount /mnt_root");
		if ( rmdir ("/mnt_root") ) perror("Can't remove /mnt_root");
	}
}

int trymount (const char* source, const char* target)
{
	return	mount(source, target, "iso9660", MS_RDONLY, NULL) &&
		mount(source, target, "ext3",    MS_RDONLY, NULL) &&
		mount(source, target, "ext2",    MS_RDONLY, NULL) &&
		mount(source, target, "minix",   MS_RDONLY, NULL) &&
		mount(source, target, "vfat",    MS_RDONLY, NULL);
}

void trygets(char *s, int len)
{
	s[0]=0;
	if (fgets(s, len, stdin) == NULL) {
		if (ferror(stdin)) perror("fgets");
		else printf("EOF\n");

		sleep(1);
		execl("/linuxrc", "/linuxrc", NULL);
		printf("\nCan't start /linuxrc!! Life sucks.\n\n");
		exit(0);
	}
	/* guarantee a 0 termination and remove the trailing newline */
	s[len-1]=0;
	if (strlen(s) > 0) s[strlen(s)-1]=0;
}

void trywait(pid)
{
	if (pid < 0) perror("fork");
	else waitpid(pid, NULL, 0);
}

#define tryexeclp(file, arg, ...) ( { \
	int pid; \
\
	if ( (pid = fork()) == 0 ) { \
		execlp(file, arg, __VA_ARGS__); \
		perror(file); \
		exit(1); \
	} \
\
	trywait(pid); \
} )

void httpload() 
{
	int fd[2];
	char baseurl[200];
	char filename[100];
	char url[500];
	int pid_wget, pid_tar;

	printf("Enter base URL (e.g. http://1.2.3.4/rock): ");
	fflush(stdout);

	trygets(baseurl, 200);
	if (baseurl[0] == 0) return;

	printf("Select a stage 2 image file:\n\n"
	       "     1. %s\n     2. %s\n\n"
	       "Enter number or image file name (default=1): ",
	       STAGE_2_BIG_IMAGE, STAGE_2_SMALL_IMAGE);

	trygets(filename, 100);
	if (filename[0] == 0) strcpy(filename, STAGE_2_BIG_IMAGE);
	else if (!strcmp(filename, "1")) strcpy(filename, STAGE_2_BIG_IMAGE);
	else if (!strcmp(filename, "2")) strcpy(filename, STAGE_2_SMALL_IMAGE);

	exit_linuxrc=1;
	snprintf(url, 500, "%s/%s", baseurl, filename);

	printf("[ %s ]\n", url);
	setenv("ROCK_INSTALL_SOURCE_URL", baseurl, 1);

	exit_linuxrc=1;
	if ( mkdir("/mnt_root", 700) )
		{ perror("Can't create /mnt_root"); exit_linuxrc=0; }

	if ( mount("none", "/mnt_root", "tmpfs", 0, TMPFS_OPTIONS) )
		{ perror("Can't mount /mnt_root"); exit_linuxrc=0; }

	if ( pipe(fd) < 0 )
		{ perror("Can't create pipe"); exit_linuxrc=0; } 

	if ( (pid_wget = fork()) == 0 ) {
		dup2(fd[1],1); close(fd[0]); close(fd[1]);
		execlp("wget", "wget", "-O", "-", url, NULL);
		perror("wget");
		_exit(1);
	}

	if ( (pid_tar = fork()) == 0 ) {
		dup2(fd[0],0); close(fd[0]); close(fd[1]);
		execlp("tar", "tar", STAGE_2_COMPRESS_ARG,
		       "-C", "/mnt_root", "-xf", "-", NULL);
		perror("tar");
		_exit(1);
	}

	close(fd[0]); close(fd[1]);
	trywait(pid_wget); trywait(pid_tar);
	printf("finished ... now booting 2nd stage\n");
	doboot();
}

/* check wether a file is a directory */
int is_dir(const struct dirent *entry) {
	struct stat tmpstat;
	stat(entry->d_name, &tmpstat);
	return S_ISDIR(tmpstat.st_mode);
}

/* this is used in the module loading shell for sorting dirs before files */
int dirs_first_sort(const struct dirent **a, const struct dirent **b) {
	if(is_dir(*a)) {
		if(is_dir(*b)) return 0;
		else return 1;
	} else if(is_dir(*b)) {
		return -1;
	} else return 0;
}

/* this is used in the modules loading shell to filter out kernel objects */
int module_filter(const struct dirent *entry) {
	if(is_dir(entry)) {
		if(!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) return 0;
		else return 1;
	} else if (!strcmp(entry->d_name+(strlen(entry->d_name) - mod_suffix_len), mod_suffix)) return 1;
	return 0;
}

/* this starts the module loading shell */
void load_modules(char* directory){
	struct dirent **namelist;
	int cnt, n, len, needmodhdr = 1, needdirhdr = 1;
	int loader_res=0;
	char filename[256], input[256];
	char *execargs[100];

	printf("module loading shell\n\n");
	printf("you can navigate through the filestem with 'cd'. for loading a module\n");
	printf("simply enter the shown name, to exit press enter on a blank line.\n\n");

	while(1) {
		if(chdir(directory)) {
			perror("chdir");
		}

		n = scandir(".", &namelist, module_filter, dirs_first_sort);
		if (n < 0) {
			perror("scandir");
		}
		getcwd(directory, 255);

		while(n--) {
			strcpy(filename, namelist[n]->d_name);
			len = strlen(filename);
	
			if(is_dir(namelist[n])) {
				/* first visit to this function, show header */
				if(needdirhdr == 1) {
					printf("directories:\n	");
					needdirhdr = 0; cnt = 1;
				}
				printf("[%-15s]",filename);
				if(cnt % 4 == 0) printf("\n	");
				cnt++;
			} else { 
				/* finished directories, show module header */
				if(needmodhdr == 1) {
					if(needdirhdr == 0) printf("\n");
					printf("kernel modules:\n	");
					needmodhdr = 0; cnt = 1;
				}
				filename[len-mod_suffix_len] = 0;
				printf("%-15s",filename);
				if(cnt % 4 == 0) printf("\n	");
				cnt++;
			}
	
			free(namelist[n]);
		}
		free(namelist);
		needmodhdr = 1; needdirhdr = 1;
	
		printf("\n[%s]> ", directory);
		fflush(stdout);
	
		input[0]=0; fgets(input, 256, stdin); input[255]=0;
		if (strlen(input) > 0) input[strlen(input)-1]=0;
		if (input[0] == 0) return;
	
		if(!strncmp(input, "cd ", 3)) {
			/* absolute or relative pathname? */
			if(input[3] == '/') {
				strcpy(filename, input+3);
			} else {
				strcpy(filename, directory);
				strcat(filename, "/");
				strcat(filename, input+3);
			}
			free(directory);
			directory = (char*)malloc(strlen(filename)+1);
			strcpy(directory, filename);
		} else {
			snprintf(filename, 256, "%s%s", strtok(input, " "), mod_suffix);
			execargs[0] = mod_loader; execargs[1] = filename;
			for (n=2; (execargs[n] = strtok(NULL, " ")) != NULL; n++) ;

			if ( ! access(filename, R_OK) ) {
				if ( fork() == 0 ) {
					execvp(execargs[0], execargs);
					printf("Can't start %s!\n", execargs[0]);
					exit(1);
				}
				wait(&loader_res);
				if(WEXITSTATUS(loader_res) != 0)
					printf("error: module loader finished unsuccesfully!\n");
				else 
					printf("module loader finished succesfully.\n");
			} else {
				printf("%s: no such module found! try again... (enter=exit)\n", filename);
			}
		}

		fflush(stdout);
	}
	return;
}

int getdevice(char* devstr, int devlen, int cdroms, int floppies, int autoboot)
{
	char *devicelists[2] = { "/dev/cdroms/cdrom%d", "/dev/floppy/%d" };
	char *devicenames[2] =
	{ "CD-ROM #%d (IDE/ATAPI or SCSI)", "FDD (Floppy Disk Drive) #%d" };
	char *devn[10], *desc[10];
	char text[100], devicefile[100];
	int nr=0;
	int i, tmp_nr;

	if (!cdroms && !floppies)
		return -1;

	for (i = 0; i < 2; i++) {
		if ( (0 == i) && (!cdroms) ) continue;
		if ( (1 == i) && (!floppies) ) continue;

		for (tmp_nr = 0; tmp_nr < 10; ++tmp_nr) {
			sprintf(devicefile, devicelists[i], tmp_nr);
			sprintf(text, devicenames[i], tmp_nr+1);

			if ( access (devicefile, R_OK) ) break;
			
			desc[nr] = strdup (text);
			devn[nr++] = strdup (devicefile);
		}
	}

	if (!nr) return -1;
	
	desc[nr] = devn[nr] = NULL;

	for (nr=0; desc[nr]; nr++) {
		printf("     %d. %s\n", nr, desc[nr]);
	}

	printf("\nEnter number or device file name (default=0): ");
	fflush(stdout);

	if ( !autoboot ) {
		trygets(text, 100);
	} else {
		printf("0\n");
		strcpy(text, "0");
	}

	if (text[0] == 0)
		strcpy(text, "0");

	while (1) {
		if ( ! access(text, R_OK) ) {
			strncpy(devstr, text, devlen);
			break;
		}

		if (atoi(text) >= 0 && atoi(text) < nr) {
			strncpy(devstr, devn[atoi(text)], devlen);
			break;
		}

		printf("No such device found. Try again (enter=back): ");
		fflush(stdout);
	 	trygets(text, 100);
		if (text[0] == 0) return -1;
	}
	
	return 1;
}

void load_ramdisk_file(int autoboot)
{
	char text[100], devicefile[100];
	char filename[100];
	int pid;

	printf("Select a device for loading the 2nd stage system from: \n\n");

	if (getdevice(devicefile, 100, 1, 1, autoboot) <= 0)
			return;
	
	printf("Select a stage 2 image file:\n\n"
	       "     1. %s\n     2. %s\n\n"
	       "Enter number or image file name (default=1): ",
	       STAGE_2_BIG_IMAGE, STAGE_2_SMALL_IMAGE);

	if ( !autoboot ) {
		trygets(text, 100);
	} else {
		printf("1\n");
		strcpy(text, "1");
	}

	if (text[0] == 0) strcpy(filename, STAGE_2_BIG_IMAGE);
	else if (! strcmp(text, "1")) strcpy(filename, STAGE_2_BIG_IMAGE);
	else if (! strcmp(text, "2")) strcpy(filename, STAGE_2_SMALL_IMAGE);
	else strcpy(filename, text);

	exit_linuxrc=1;
	printf("Using %s:%s.\n", devicefile, filename);

	if ( mkdir("/mnt_source", 700) )
		{ perror("Can't create /mnt_source"); exit_linuxrc=0; }

	if ( trymount (devicefile, "/mnt_source") )
		{ perror("Can't mount /mnt_source"); exit_linuxrc=0; }

	if ( mkdir("/mnt_root", 700) )
		{ perror("Can't create /mnt_root"); exit_linuxrc=0; }

	if ( mount("none", "/mnt_root", "tmpfs", 0, TMPFS_OPTIONS) )
		{ perror("Can't mount /mnt_root"); exit_linuxrc=0; }

	if ( (pid = fork()) == 0 ) {
		printf("Extracting 2nd stage filesystem to ram ...\n");
		snprintf(text, 100, "/mnt_source/%s", filename);
		execlp( "tar", "tar", STAGE_2_COMPRESS_ARG,
		               "-C", "/mnt_root", "-xf", text, NULL);
		printf("Can't run tar on %s!\n", filename);
		exit(1);
	}
	trywait(pid);

	if ( umount("/mnt_source") )
		{ perror("Can't umount /mnt_source"); exit_linuxrc=0; }

	if ( rmdir("/mnt_source") )
		{ perror("Can't remove /mnt_source"); exit_linuxrc=0; }

	setenv("ROCK_INSTALL_SOURCE_DEV",  devicefile, 1);
	setenv("ROCK_INSTALL_SOURCE_FILE", filename,   1);
	doboot();
}	

void activate_swap()
{
	char text[100];

	printf("\nEnter file name of swap device: ");
	fflush(stdout);

	trygets(text, 100);
	if ( text[0] ) {
		if ( swapon(text, 0) < 0 )
			perror("Can't activate swap device");
	}
}

void config_net()
{
	char dv[100]="";
	char ip[100]="";
	char gw[100]="";

	tryexeclp("ip", "ip", "addr", NULL);
	printf("\n");

	tryexeclp("ip", "ip", "route", NULL);
	printf("\n");

	printf("Enter interface name (eth0): ");
	fflush(stdout);
	trygets(dv, 100);
	if (dv[0] == 0) strcpy(dv, "eth0");

	printf("Enter ip (192.168.0.254/24): ");
	fflush(stdout);
	trygets(ip, 100);
	if (ip[0] == 0) strcpy(ip, "192.168.0.254/24");

	tryexeclp("ip", "ip", "addr", "add", ip, "dev", dv, NULL);
	tryexeclp("ip", "ip", "link", "set", dv, "up", NULL);

	printf("Enter default gateway (none): ");
	fflush(stdout);
	trygets(gw, 100);
	if (gw[0] != 0)
		tryexeclp("ip", "ip", "route", "add",
		          "default", "via", gw, NULL);
	printf("\n");

	tryexeclp("ip", "ip", "addr", NULL);
	printf("\n");

	tryexeclp("ip", "ip", "route", NULL);
}

void autoload_modules()
{
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

void checkisomd5()
{
	char devicefile[100];

	printf("Select a device for checking: \n\n");
	
	if (getdevice(devicefile, 100, 1, 0, 0) <= 0)
		return;

	mediaCheckFile(devicefile, 0);
	
	printf("\nPress Return key to continue."); (void)getchar();
}

int main()
{
	char text[100];
	int input=1;

	if ( mount("none", "/dev", "devfs", 0, NULL) && errno != EBUSY )
		perror("Can't mount /dev");

	if ( mount("none", "/sys", "sysfs", 0, NULL) && errno != EBUSY )
		perror("Can't mount /sys (not fatal)");

	if ( mount("none", "/proc", "proc", 0, NULL) && errno != EBUSY )
		perror("Can't mount /proc");

	/* Only print important stuff to console */
	klogctl(8, NULL, 3);

	mod_load_info(mod_loader, mod_dir, mod_suffix);
	mod_suffix_len = strlen(mod_suffix);

	autoload_modules();
	if ( getenv("autoboot") ) {
		load_ramdisk_file(1);
	}

	printf("\n\
     ============================================\n\
     ===   ROCK Linux 1st stage boot system   ===\n\
     ============================================\n\
\n\
The ROCK Linux install / rescue system boots up in two stages. You\n\
are now in the first of this two stages and if everything goes right\n\
you will not spend much time here. Just load your SCSI and networking\n\
drivers (if needed) and configure the installation source so the\n\
2nd stage boot system can be loaded and you can start the installation.\n");

	while (exit_linuxrc == 0)
	{
		printf("\n\
     0. Load 2nd stage system from local device\n\
     1. Load 2nd stage system from network\n\
     2. Configure network interfaces (IPv4 only)\n\
     3. Load kernel modules from this disk\n\
     4. Load kernel modules from another disk\n\
     5. Activate already formatted swap device\n\
     6. Execute a (kiss) shell if present (for experts!)\n\
     7. Validate a CD/DVD against its embedded checksum\n\
\n\
What do you want to do [0-8] (default=0)? ");
		fflush(stdout);

		trygets(text, 100);
		input=atoi(text);
		
		switch (input) {
		case 0:
		  load_ramdisk_file(0);
		  break;
		
		case 1:
		  httpload();
		  break;

		case 2:
		  config_net();
		  break;
		  
		case 3:
		  load_modules(mod_dir);
		  break;

		case 4:
		  if ( mkdir("/mnt_floppy", 700) )
		    perror("Can't create /mnt_floppy");
		  
		  if ( trymount("/dev/floppy/0", "/mnt_floppy") )
		    load_modules("/mnt_floppy");
		  
		  if ( umount("/mnt_floppy") )
		    perror("Can't umount /mnt_floppy");
		  
		  if ( rmdir("/mnt_floppy") )
		    perror("Can't remove /mnt_floppy");
		  break;
		  
		case 5:
		  activate_swap();
		  break;
		  
		case 6:
		  exec_sh();
		  break;
		  
		case 7:
		  checkisomd5();
		  break;
		  
		default:
		  perror ("No such option present!");
		}
	}
	
	sleep(1);
	execl("/linuxrc", "/linuxrc", NULL);
	printf("\nCan't start /linuxrc!! Life sucks.\n\n");
	return 0;
}

