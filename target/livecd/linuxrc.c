/*
 * --- ROCK-COPYRIGHT-NOTE-BEGIN ---
 * 
 * This copyright note is auto-generated by ./scripts/Create-CopyPatch.
 * Please add additional copyright information _after_ the line containing
 * the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
 * the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
 * 
 * ROCK Linux: rock-src/target/livecd/linuxrc.c
 * ROCK Linux is Copyright (C) 1998 - 2003 Clifford Wolf
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

	strcpy(mod_loader, "/bin-static/insmod");
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
	DEBUG("doboot starting...");
	if ( access("/sbin/init", R_OK) ) { perror("Can't find /sbin/init"); }
	else {
		/* not sure why, but i get 'bad address' if i don't wait a bit here... */
		sleep(1);
		execlp("/sbin/init","init",NULL);
		perror("execlp /sbin/init failed");
	}
	DEBUG("doboot returning - bad!");
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
	if(rmdir(directory) != 0) {
		perror("could not delete just-left meant-to-be-empty directory");
		ret = -1;
	}

	return ret;
}

/* symlink most files in /etc */
int make_etc_symlinks() 
{
	struct dirent **namelist;
	char source[256], target[256], oldcwd[100];
	int n, ret=0;

	getcwd(oldcwd, 100);
	chdir("/ROCK/etc");

	n = scandir(".", &namelist, no_dot_dirs_filter, NULL);
	if (n < 0) {
		perror("scandir"); ret = -1;
	}

	while(n--) {
		snprintf(source, 256, "/ROCK/etc/%s",namelist[n]->d_name);
		snprintf(target, 256, "/etc/%s",namelist[n]->d_name);

		if (access(target, R_OK) == 0) {
			printf("shyly skipping symlink for %s - already exists!\n", target);
		} else if (symlink(source, target) != 0) {
			printf("error in symlinking %s -> %s\n",source,target);
			ret = -1;
		}

		free(namelist[n]);
	}
	free(namelist);

	chdir(oldcwd);

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
	int ret = 0;
	/* we need to set umask to 00 so we can set 777 perms */
	umask(00);

	DEBUG("symlinking /bin, /sbin, /boot, /opt");
	/* simple symlinking */
	if(symlink("/ROCK/bin","/bin") != 0) { perror("/bin symlink FAILED"); ret=-1; }
	if(symlink("/ROCK/sbin","/sbin") != 0) { perror("/sbin symlink FAILED"); ret=-1; }
	if(symlink("/ROCK/boot","/boot") != 0) { perror("/boot symlink FAILED"); ret=-1; }
	if(symlink("/ROCK/opt","/opt") != 0) { perror("/opt symlink FAILED"); ret=-1; }

	DEBUG("creating /tmp");
	/* if /tmp isn't empty, this is gonna blow... */	
	if(rmdir("/tmp") != 0) { perror("unable to remove old /tmp"); ret=-1; }
	if(mkdir("/ramdisk/tmp", 0777) != 0) { perror("unable to create /ramdisk/tmp"); ret=-1; }
	if(symlink("/ramdisk/tmp", "/tmp") != 0) { perror("/tmp symlink FAILED"); ret=-1; }

	DEBUG("creating /home");
	if(mkdir("/ramdisk/home", 0755) != 0) { perror("unable to create /ramdisk/home"); ret=-1; }
	if(symlink("/ramdisk/home", "/home") != 0) { perror("/home symlink FAILED"); ret=-1; }

	DEBUG("symlinking /usr");
	/* usr is just a symlink to / , that's why it works */
	if(unlink("/usr") != 0) { perror("unable to remove old /usr"); ret=-1; }
	if(symlink("/ROCK/usr","/usr") != 0) { perror("/usr symlink FAILED"); ret=-1; }
	
	DEBUG("symlinking /var");
	if(mkdir("/ramdisk/var", 0755) != 0) { perror("unable to create /ramdisk/var"); ret=-1; }
	if(symlink("/ramdisk/var", "/var") != 0) { perror("/var symlink FAILED"); ret=-1; }

	DEBUG("removing and symlinking /lib");
	if(rm_recursive("/lib") != 0) { printf("removal of /lib FAILED\n"); ret=-1; }
	if(symlink("/ROCK/lib", "/lib") != 0) { perror("/lib symlink FAILED"); ret=-1; }

	DEBUG("removing /sbin-static and /bin-static");
	if(unlink("/sbin-static") != 0) { perror("error removing /sbin-static"); ret=-1; }
	if(rm_recursive("/bin-static") != 0) { printf("removal of /bin-static FAILED\n"); ret=-1; }
	fflush(stdout);

	DEBUG("preparing /etc");
	/* the /etc directory is a bit special */
	if(make_etc_symlinks() != 0) { printf("error while symlinking individual files in /etc!\n"); ret=-1; }
	/* remove some files that either need to be writable or need to be replaced */
	if(unlink("/etc/mtab") != 0) { perror("unable to remove /etc/mtab!"); ret=-1; }
	if(unlink("/etc/passwd") != 0) { perror("unable to remove /etc/passwd!"); ret=-1; }
	if(unlink("/etc/group") != 0) { perror("unable to remove /etc/group!"); ret=-1; }
	if(unlink("/etc/shadow") != 0) { perror("unable to remove /etc/shadow!"); ret=-1; }
	if(unlink("/etc/X11") != 0) { perror("unable to remove /etc/X11 symlink!"); ret=-1; }
	if(mkdir("/etc/X11",0755) != 0) { perror("unable to create /etc/X11!"); ret=-1; }
	if(mkdir("/etc/X11/xkb",0755) != 0) { perror("unable to create /etc/X11/xkb!"); ret=-1; }

	/* etc/mtab must not contain a duplicate rootfs entry*/
	umask(022);
	FILE* orig = fopen("/proc/mounts","r");
	FILE* mod = fopen("/etc/mtab","w");
	char buf[256];

	DEBUG("modifying /etc/mtab");
	while(fgets(buf, 256, orig) != NULL) {
		if(memcmp(buf,"rootfs",6) == 0) continue;
		else fputs(buf, mod);
	}
	fclose(orig); fclose(mod); buf[1]=0;

	/* add rocker to /etc/passwd and change root's home to /home/root */
	DEBUG("modifying /etc/passwd");
	orig = fopen("/ROCK/etc/passwd","r");
	mod = fopen("/etc/passwd","w");
        while(fgets(buf, 256, orig) != NULL) {
                if(memcmp(buf,"root",4) != 0) fputs(buf, mod);
                else fputs("root:x:0:0:root:/home/root:/bin/bash\n",mod);
        }
        fputs("rocker:x:1000:100:ROCK Live CD User:/home/rocker:/bin/bash\n",mod);
        fclose(orig); fclose(mod); buf[1]=0;

        /* add rocker to /etc/shadow */
	umask(066);
	DEBUG("modifying /etc/shadow");
        orig = fopen("/ROCK/etc/shadow","r");
        mod = fopen("/etc/shadow","w");
        while(fgets(buf, 256, orig) != NULL) {
		if(memcmp(buf,"root",4) != 0) fputs(buf, mod);
		else fputs("root:$1$1YssESn0$Y9LvBGGXpsZhjNKZ0x8OM/:12548::::::\n",mod);
	}
        fputs("rocker:$1$//TuI8QD$kTxVesUbGLNKuxILuK2UN/:12548:0:99999:7:::\n",mod);
        fclose(orig); fclose(mod); buf[1]=0;

        /* add rocker to group 'sound' */
	int fnd = 0;
	umask(022);
	DEBUG("modifying /etc/group");
        orig = fopen("/ROCK/etc/group","r");
        mod = fopen("/etc/group","w");
        while(fgets(buf, 256, orig) != NULL) {
                if(memcmp(buf,"sound",5) != 0) fputs(buf, mod);
                else {
			fputs("sound:x:17:rocker\n",mod);
			fnd = 1;
		}
        }
	if(!fnd) fputs("sound:x:17:rocker\n",mod);
        fclose(orig); fclose(mod); buf[1]=0;

	/* copy over XF86Config */
	DEBUG("modifying /etc/X11/XF86Config");
	orig = fopen("/ROCK/etc/X11/XF86Config","r");
        mod = fopen("/etc/X11/XF86Config","w");
        while(fgets(buf, 256, orig) != NULL) fputs(buf, mod);
	fclose(orig); fclose(mod); buf[1]=0;

	/* copy over resolv.conf */
	DEBUG("modifying /etc/resolv.conf");
	unlink("/etc/resolv.conf");
	orig = fopen("/ROCK/etc/resolv.conf","r");
        mod = fopen("/etc/resolv.conf","w");
        while(fgets(buf, 256, orig) != NULL) fputs(buf, mod);
	fclose(orig); fclose(mod); buf[1]=0;

	/* change modules.conf to place it's modules.dep in /etc */
	DEBUG("modifying /etc/modules.conf");
	unlink("/etc/modules.conf");
	orig = fopen("/ROCK/etc/modules.conf","r");
        mod = fopen("/etc/modules.conf","w");
        while(fgets(buf, 256, orig) != NULL) fputs(buf, mod);
	fputs("depfile=/etc/modules.dep\n",mod);
	fputs("generic_stringfile=/etc/modules.generic_string\n",mod);
	fputs("pcimapfile=/etc/modules.pcimap\n",mod);
	fputs("isapnpmapfile=/etc/modules.isapnpmap\n",mod);
	fputs("usbmapfile=/etc/modules.usbmap\n",mod);
	fputs("parportmapfile=/etc/modules.parportmap\n",mod);
	fputs("ieee1394mapfile=/etc/modules.ieee1394map\n",mod);
	fputs("pnpbiosmapfile=/etc/modules.pnpbiosmap\n",mod);
	fclose(orig); fclose(mod); buf[1]=0;
	umask(00);

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

	/* create needed directories in /var */
	DEBUG("preparing /var");
	if(mkdir("/var/run",0755) != 0 ) { perror("could not create /var/run"); ret=-1; }
	if(mkdir("/var/lock",0755) != 0 ) { perror("could not create /var/lock"); ret=-1; }
	if(mkdir("/var/tmp",0777) != 0 ) { perror("could not create /var/tmp"); ret=-1; }
	if(mkdir("/var/log",0755) != 0 ) { perror("could not create /var/log"); ret=-1; }
	if(mkdir("/var/lib",0755) != 0 ) { perror("could not create /var/lib"); ret=-1; }
	if(mkdir("/var/lib/xkb",0755) != 0 ) { perror("could not create /var/lib/xkb"); ret=-1; }
	if(symlink("/var/lib/xkb","/etc/X11/xkb/compiled")!=0) 
		{ perror("could not symlink /var/lib/xkb to /etc/X11/xkb/compiled"); ret=-1; }
	if(mkdir("/var/state",0755) != 0 ) { perror("could not create /var/state"); ret=-1; }
	if(mkdir("/var/state/dhcp",0755) != 0 ) { perror("could not create /var/state/dhcp"); ret=-1; }
	if(mkdir("/var/rockplug",0755) != 0 ) { perror("could not create /var/rockplug"); ret=-1; }
	if(mkdir("/var/rockplug/ieee1394",0755) != 0 ) { perror("could not create /var/rockplug/ieee1394"); ret=-1; }
	if(mkdir("/var/rockplug/isapnp",0755) != 0 ) { perror("could not create /var/rockplug/isapnp"); ret=-1; }
	if(mkdir("/var/rockplug/net",0755) != 0 ) { perror("could not create /var/rockplug/net"); ret=-1; }
	if(mkdir("/var/rockplug/pci",0755) != 0 ) { perror("could not create /var/rockplug/pci"); ret=-1; }
	if(mkdir("/var/rockplug/scsi",0755) != 0 ) { perror("could not create /var/rockplug/scsi"); ret=-1; }
	if(mkdir("/var/rockplug/usb",0755) != 0 ) { perror("could not create /var/rockplug/usb"); ret=-1; }
	
	/* add rocker's home, change owner */
	DEBUG("creating homes");
	if(mkdir("/home/rocker",0755) != 0 ) { perror("could not create /home/rocker"); ret=-1; }
	if(chown("/home/rocker",1000,100) != 0) { perror("could not chown /home/rocker to rocker:users"); ret=-1; }
	/* root's home */
	if(mkdir("/home/root",0700) != 0 ) { perror("could not create /home/root"); ret=-1; }

	umask(022);
	return ret;
}

void load_ramdisk_file() {
	char text[120], devicefile[100];
	char filename[100];
	int ret = 0;

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

	DEBUG("mounting loop device on /ROCK ... ");
	if( mount("/dev/loop/0", "/ROCK", "squashfs", MS_RDONLY, NULL) ) 
		{ perror("Can't mount squashfs on /ROCK!"); return; }

	DEBUG("mounting tmpfs on /ramdisk");	
	if ( mount("none", "/ramdisk", "tmpfs", 0, NULL) )
		{ perror("Can't mount /ramdisk"); return; }

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
		execlp("gawk", "gawk", "-f", "/bin-static/hwscan", NULL);
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
	        execl("/bin-static/kiss", "kiss", "-E", NULL);
		perror("kiss");
		_exit(1);
	}
	trywait(rc);
}

int main(int argc, char** argv)
{
	int args;

	if (argc > 1) {
		do_debug = 1;
		DEBUG("got an argument, switching debug mode on!");
		for(args=1; args<argc; args++) {
			DEBUG("Arg%d:%s",args,argv[args]);
		}
	}

	if ( mount("none", "/dev", "devfs", 0, NULL) && errno != EBUSY )
		perror("Can't mount /dev");

	if ( mount("none", "/proc", "proc", 0, NULL) && errno != EBUSY )
		perror("Can't mount /proc");

	/* Only print important stuff to console */
	klogctl(8, NULL, 3);

	mod_load_info(mod_loader, mod_dir, mod_suffix);
	mod_suffix_len = strlen(mod_suffix);

	autoload_modules();

	printf("\n\
     ============================================\n\
     ===   ROCK Linux 1st stage boot system   ===\n\
     ============================================\n\
\n\
The ROCK Linux live CD system boots up in two stages. You are now in\n\
the first of this two stages and if everything goes right you will not\n\
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
	if(access("/bin-static/kiss",R_OK) == 0) execl("/bin-static/kiss", "/bin-static/kiss", NULL);

	printf("\nCan't start a shell!!\n\nPlease send a bug report with your configuration to fake@rocklinux.org\n\n");
	return 0;
}

