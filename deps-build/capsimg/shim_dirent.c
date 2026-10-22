/*
 * Win32 implementation of the dirent.h shim for the MSVC build of the
 * SPS decoder library (CAPSImg). Uses the ANSI FindFirstFileA API.
 *
 * Copyright 2026 Drazen Hudoletnjak
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdlib.h>
#include <string.h>

#include "dirent.h"

struct shim_DIR {
	HANDLE h;
	WIN32_FIND_DATAA fd;
	int first;
	struct dirent ent;
};

DIR *opendir(const char *dirname)
{
	char pattern[MAX_PATH * 2];
	size_t len = strlen(dirname);
	DIR *d;

	if (len + 3 > sizeof pattern)
		return NULL;
	strcpy(pattern, dirname);
	if (len && pattern[len - 1] != '\\' && pattern[len - 1] != '/')
		strcat(pattern, "\\");
	strcat(pattern, "*");

	d = (DIR *)calloc(1, sizeof(DIR));
	if (!d)
		return NULL;
	d->h = FindFirstFileA(pattern, &d->fd);
	if (d->h == INVALID_HANDLE_VALUE) {
		free(d);
		return NULL;
	}
	d->first = 1;
	return d;
}

struct dirent *readdir(DIR *d)
{
	if (!d->first && !FindNextFileA(d->h, &d->fd))
		return NULL;
	d->first = 0;
	strncpy(d->ent.d_name, d->fd.cFileName, sizeof d->ent.d_name - 1);
	d->ent.d_name[sizeof d->ent.d_name - 1] = 0;
	d->ent.d_reclen = (unsigned short)strlen(d->ent.d_name);
	return &d->ent;
}

int closedir(DIR *d)
{
	FindClose(d->h);
	free(d);
	return 0;
}
