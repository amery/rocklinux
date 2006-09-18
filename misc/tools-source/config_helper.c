/* Bash (wallclock-time) profiler. Written by Clifford Wolf.
 *
 * Usage:
 *	gcc -shared -fPIC -Wall -o config_helper.so config_helper.c
 *	enable -f ./config_helper.so cfghlp
 *
 * Note: This builtin trusts that it is called correctly. If it is
 * called the wrong way, segfaults etc. are possible.
 */


/* Some declarations copied from bash-2.05b headers */

#include <stdint.h>

typedef struct word_desc {
	char *word;
	int flags;
} WORD_DESC;

typedef struct word_list {
	struct word_list *next;
	WORD_DESC *word;
} WORD_LIST;

typedef int sh_builtin_func_t(WORD_LIST *);

#define BUILTIN_ENABLED 0x1

struct builtin {
	char *name;
	sh_builtin_func_t *function;
	int flags;
	char * const *long_doc;
	const char *short_doc;
	char *handle;
};


/* my hellobash builtin */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/time.h>
#include <sys/types.h>
#include <regex.h>

struct package;
struct package {
	int status;
	char stages[10];
	char *prio;
	char *repository;
	char *name;
	char *alias;
	char *version;
	char *prefix;
	/* flags must end with a space character
		(for easily searching for flags). */
	char *flags;
	struct package *next;
};

struct package *package_list = 0;

int read_pkg_list(const char *file) {
	FILE *f = fopen(file, "r");
	struct package *pkg = package_list;
	struct package *pkg_tmp;
	char line[1024], *tok;
	int i;

	while (pkg) {
		free(pkg->prio);
		free(pkg->repository);
		free(pkg->name);
		free(pkg->alias);
		free(pkg->version);
		free(pkg->prefix);
		free(pkg->flags);
		pkg = (pkg_tmp=pkg)->next;
		free(pkg_tmp);
	}

	pkg = package_list = 0;

	while (fgets(line, 1024, f)) {
		pkg_tmp = calloc(1, sizeof(struct package));

		tok = strtok(line, " ");
		pkg_tmp->status = line[0] == 'X';

		tok = strtok(0, " ");
		for (i=0; i<10; i++)
			pkg_tmp->stages[i] = tok[i] != '-' ? tok[i] : 0;

		tok = strtok(0, " ");
		pkg_tmp->prio = strdup(tok);

		tok = strtok(0, " ");
		pkg_tmp->repository = strdup(tok);

		tok = strtok(0, " ");
		char *c = strchr(tok, '=');
		if (c)
		{
			pkg_tmp->name = malloc(c-tok+1);
			pkg_tmp->name[c-tok] = '\0';
			strncpy(pkg_tmp->name, tok, c-tok);
			pkg_tmp->alias = strdup(c+1);
		}
		else 
		{
			pkg_tmp->name = strdup(tok);
			pkg_tmp->alias = strdup(tok);
		}

		tok = strtok(0, " ");
		pkg_tmp->version = strdup(tok);

		tok = strtok(0, " ");
		pkg_tmp->prefix = strdup(tok);

		tok = strtok(0, "\n");
		tok[strlen(tok)-1] = 0;
		pkg_tmp->flags = strdup(tok);

		if ( !package_list )
			pkg=package_list=pkg_tmp;
		else
			pkg=pkg->next=pkg_tmp;
	}

	fclose(f);

	return 0;
}

int write_pkg_list(const char *file) {
	FILE *f = fopen(file, "w");
	struct package *pkg = package_list;
	int i;

	while (pkg) {
		fprintf(f, "%c ", pkg->status ? 'X' : 'O');
		for (i=0; i<10; i++)
			fprintf(f, "%c", pkg->stages[i] ? pkg->stages[i] : '-');
		fprintf(f, " %s %s %s", pkg->prio, pkg->repository, pkg->name);
		if (strcmp(pkg->name, pkg->alias))
			fprintf(f, "=%s", pkg->alias);
		fprintf(f, " %s %s %s0\n", pkg->version, pkg->prefix, pkg->flags);
		pkg = pkg->next;
	}

	fclose(f);
	return 0;
}

regex_t * create_pkg_regex(const char* pattern)
{
	char fullpattern[512];
	snprintf(fullpattern, 512, "[= ]%s ", pattern);

	regex_t *preg = malloc(sizeof(regex_t));
	int errcode = regcomp(preg, fullpattern,
		REG_EXTENDED | REG_ICASE | REG_NOSUB | REG_NEWLINE);
	if (errcode)
	{
		int errbuf_size = regerror(errcode, preg, 0, 0);
		char *errbuf = malloc(errbuf_size);
		regerror(errcode, preg, errbuf, errbuf_size);
		fprintf(stderr, "config_helper: create_pkg_regex(%s): %s\n",
		 	pattern, errbuf);
		free(errbuf);
		return NULL;
	}
	return preg;
}

char * create_pkg_line(struct package *pkg)
{
	char *line = calloc(1024, sizeof(char));
	int i, offset = 0;

	offset += snprintf(line+offset, 1024-offset, "%c ",
		pkg->status ? 'X' : 'O');
	for (i=0; i<10; i++)
		offset += snprintf(line+offset, 1024-offset, "%c",
			pkg->stages[i] ? pkg->stages[i] : '-');
	offset += snprintf(line+offset, 1024-offset, " %s %s %s",
		pkg->prio, pkg->repository, pkg->name);
	if (strcmp(pkg->name, pkg->alias))
		offset += snprintf(line+offset, 1024-offset, "=%s", pkg->alias);
	offset += snprintf(line+offset, 1024-offset, " %s %s %s0\n",
		pkg->version, pkg->prefix, pkg->flags);

	return line;
}

int pkgcheck(const char *pattern, const char *mode)
{
	struct package *pkg = package_list;

	char fullpattern[512];
	snprintf(fullpattern, 512, "[= ]%s ", pattern);

	regex_t *preg = create_pkg_regex(pattern);
	if (preg == NULL) return 0;

	while (pkg) {
		char *line = create_pkg_line(pkg);
		int match = !regexec(preg, line, 0, 0, 0);
		free(line);

		if (match)
		{

			switch (mode[0]) {
				case 'X':
					if (pkg->status) goto found;
					break;
				case 'O':
					if (!pkg->status) goto found;
					break;
				case '.':
					goto found;
			}
		}
		pkg = pkg->next;
	}

 	regfree(preg);
	return 1;

found:
 	regfree(preg);
	return 0;
}

int pkgswitch(int mode, char **args)
{
	struct package *pkg = package_list;
	struct package *last_pkg = 0;
	struct package *pkg_tmp = 0;

	regex_t *preg = create_pkg_regex(args[0]);
	if (preg == NULL) return 0;

	while (pkg) {
		char *line = create_pkg_line(pkg);
		int match = !regexec(preg, line, 0, 0, 0);
		free(line);

		if (match) {
			if ( !mode ) {
				*(last_pkg ? &(last_pkg->next) : &package_list) = pkg->next;
				free(pkg->prio);
				free(pkg->repository);
				free(pkg->name);
				free(pkg->alias);
				free(pkg->version);
				free(pkg->prefix);
				free(pkg->flags);
				pkg = (pkg_tmp=pkg)->next;
				free(pkg_tmp);
				continue;
			} else
				pkg->status = mode == 1;
		}
		pkg = (last_pkg=pkg)->next;
	}

	return 0;
}

int pkgfork(char *pkgname, char *xpkg, char** opt)
{

	struct package *fork, *pkg;
	int i, k;

	for (pkg = package_list; pkg; pkg = pkg->next)
		if (!strcmp(pkg->alias, pkgname))
			break;
	if (!pkg) return 1;

	fork = calloc(1, sizeof(struct package));

	fork->status = pkg->status;
	for (k=0; k<10; k++)
		fork->stages[k] = pkg->stages[k];
	fork->prio = strdup(pkg->prio);
	fork->repository = strdup(pkg->repository);
	fork->name = strdup(pkgname);
	fork->alias = strdup(xpkg);
	fork->version = strdup(pkg->version);
	fork->prefix = strdup(pkg->prefix);
	fork->flags = strdup(pkg->flags);

	fork->next = pkg->next;
	pkg->next = fork;

	for (i=0; *opt[i] && *opt[i+1]; i+=2)
	{
		if (!strcmp(opt[i], "status"))
			fork->status= opt[i+1][0] == 'X';

		else if (!strcmp(opt[i], "stages"))
			for (k=0; k<10; k++)
				fork->stages[k] = opt[i+1][k] != '-' ? opt[i+1][k] : 0;

		else if (!strcmp(opt[i], "priority"))
		{
			free(fork->prio);
			fork->prio = strdup(opt[i+1]);
		}

		else if (!strcmp(opt[i], "version"))
		{
			free(fork->version);
			fork->version = strdup(opt[i+1]);
		}

		else if (!strcmp(opt[i], "prefix"))
		{
			free(fork->prefix);
			fork->prefix = strdup(opt[+1]);
		}

		else if (!strcmp(opt[i], "flag"))
		{
			char buf[512], flag[512];
			snprintf(flag, 512, " %s ", opt[i+1]);
			if (! strstr(fork->flags, flag))
			{
				free(fork->flags);
				snprintf(buf, 512, "%s%s ", pkg->flags, opt[i+1]);
				fork->flags = strdup(buf);
			}
		}

		else if (!strcmp(opt[i], "unflag"))
		{
			char buf[512], flag[512];
			snprintf(flag, 512, " %s ", opt[i+1]);
			char *flagstart = strstr(fork->flags, flag);
			if (flagstart)
			{
				int len = flagstart - fork->flags + 1;
				strncpy(buf, fork->flags, len);
				strncpy(buf+len, flagstart+strlen(flag), 512-len);
				
				free(fork->flags);
				fork->flags = strdup(buf);
			}
		}
	}
	return 0;
}

int cfghlp_builtin(WORD_LIST *list)
{
	char *args[10];
	int i;

	for (i=0; i<9 && list; i++) {
		args[i] = list->word->word;
		list = list->next;
	}
	for (; i<10; i++) {
		args[i] = "";
	}

	if (!strcmp(args[0],"pkg_in"))
		return read_pkg_list(args[1]);

	else if (!strcmp(args[0],"pkg_out"))
		return write_pkg_list(args[1]);

	else if (!strcmp(args[0],"pkgcheck"))
		return pkgcheck(args[1], args[2]);

	else if (!strcmp(args[0],"pkgremove"))
		return pkgswitch(0, args+1);

	else if (!strcmp(args[0],"pkgenable"))
		return pkgswitch(1, args+1);

	else if (!strcmp(args[0],"pkgdisable"))
		return pkgswitch(2, args+1);

	else if (!strcmp(args[0],"pkgfork"))
		return pkgfork(args[1], args[2], args+3);

	return 1;
}

char *cfghlp_doc[] = {
	"ROCK Linux Config Helper",
	0
};

struct builtin cfghlp_struct = {
	"cfghlp",
	&cfghlp_builtin,
	BUILTIN_ENABLED,
	cfghlp_doc,
	"ROCK Linux Config Helper",
	0
};

