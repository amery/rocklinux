// --- ROCK-COPYRIGHT-NOTE-BEGIN ---
// 
// This copyright note is auto-generated by ./scripts/Create-CopyPatch.
// Please add additional copyright information _after_ the line containing
// the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
// the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
// 
// ROCK Linux: rock-src/package/base/iproute2/ipnm2nwbc.c
// ROCK Linux is Copyright (C) 1998 - 2005 Clifford Wolf
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version. A copy of the GNU General Public
// License can be found at Documentation/COPYING.
// 
// Many people helped and are helping developing ROCK Linux. Please
// have a look at http://www.rocklinux.org/ and the Documentation/TEAM
// file for details.
// 
// --- ROCK-COPYRIGHT-NOTE-END ---

#include <stdio.h>

int getbits(int n) {
	int rc=0;
	while (n) {
		if (n&1) rc++;
		n = n >> 1;
	}
	return rc;
}

int setbits(int n) {
	int rc=0;
	while (n--) {
		rc = (rc>>1)|(1<<7);
	}
	return rc;
}

int main(int argc, char ** argv) {
	int ip[4],nm[4],nw[4],bc[4],c;
	int verbose=0,nmbits=0,n;
	
	if ( argc > 1 && !strcmp(argv[1],"-v") ) verbose=1;
	
	if ( argc == 3+verbose &&
	     sscanf(argv[1+verbose],"%d.%d.%d.%d",ip,ip+1,ip+2,ip+3) == 4 &&
	     sscanf(argv[2+verbose],"%d.%d.%d.%d",nm,nm+1,nm+2,nm+3) == 4 ) {
		nmbits=getbits(nm[0])+getbits(nm[1])+
		       getbits(nm[2])+getbits(nm[3]);
	} else if ( argc == 2+verbose && sscanf(argv[1+verbose],
	            "%d.%d.%d.%d/%d",ip,ip+1,ip+2,ip+3,&nmbits) == 5 ) {
	        n=nmbits;
	        if (n>0) { nm[0]=setbits(n>8?8:n); n-=8; } else nm[0]=0;
	        if (n>0) { nm[1]=setbits(n>8?8:n); n-=8; } else nm[1]=0;
	        if (n>0) { nm[2]=setbits(n>8?8:n); n-=8; } else nm[2]=0;
	        if (n>0) { nm[3]=setbits(n>8?8:n); n-=8; } else nm[3]=0;
	} else {
		fprintf(stderr,"\n"
		    "IP and Netmask  to  Network and Broadcast  converter.\n"
		    "(C) under GPL, 1999 Clifford Wolf\n\n"
		    "Usage: %s [-v] <IP> <Netmask>\n"
		    "       %s [-v] <IP>/<Mask>\n\n"
		    "Examples: %s -v 195.170.70.72/25\n"
		    "          %s 195.170.70.72 255.255.255.128\n\n",
		    argv[0],argv[0],argv[0],argv[0]);
		return 1;
	}
	
	for (c=0; c<4; c++) {
		nw[c]=ip[c]&nm[c];
		bc[c]=nw[c]|(255&~nm[c]);
	}
	
	if ( verbose ) {
		printf("Network:   %d.%d.%d.%d / %d\n",
			nw[0],nw[1],nw[2],nw[3],nmbits);
		printf("Netmask:   %d.%d.%d.%d\n",
			nm[0],nm[1],nm[2],nm[3]);
		printf("Broadcast: %d.%d.%d.%d\n",
			bc[0],bc[1],bc[2],bc[3]);
	} else {
		printf("%d.%d.%d.%d %d.%d.%d.%d\n",nw[0],nw[1],
		       nw[2],nw[3],bc[0],bc[1],bc[2],bc[3]);
	}
	return 0;
}
