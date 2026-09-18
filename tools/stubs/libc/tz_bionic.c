/*
 * Copyright (C) 2017 The Android Open Source Project
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in
 *    the documentation and/or other materials provided with the
 *    distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
 * AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/system_properties.h>

void __bionic_get_system_tz(char* buf, size_t n) {
	char value[PROP_VALUE_MAX] = {0};
	if (__system_property_get("persist.sys.timezone", value) >= 1) {
		strlcpy(buf, value, n);
	} else {
		strlcpy(buf, "GMT", n);
		return;
	}

	if (!strcmp(buf, "GMT")) {
		// java.util.TimeZone's "GMT+xxxx" IDs disagree with POSIX about the
		// sign, and some Android-based set-top boxes used the Java form in the
		// system property, so flip the sign for native code.
		char sign = buf[3];
		if (sign == '-' || sign == '+') {
			buf[3] = (sign == '-') ? '+' : '-';
		}
	}
}

// byte[12] tzdata_version  -- "tzdata2012f\0"
// int index_offset
// int data_offset
// int final_offset
struct bionic_tzdata_header_t {
	char tzdata_version[12];
	int32_t index_offset;
	int32_t data_offset;
	int32_t final_offset;
};

#define NAME_LENGTH 40

struct index_entry_t {
	char buf[NAME_LENGTH];
	int32_t start;
	int32_t length;
	int32_t unused;
};

// Returns -2 for a soft failure (where the caller should try another file),
// -1 for a hard failure (where the caller should give up), and >= 0 is a
// file descriptor whose offset points to the data for the given olson id in
// the given file (and *entry_length is the size of the data).
static int __bionic_open_tzdata_path(const char* path, const char* olson_id, int32_t* entry_length) {
	int fd = TEMP_FAILURE_RETRY(open(path, O_RDONLY | O_CLOEXEC));
	if (fd == -1) return -2;

	struct bionic_tzdata_header_t header;
	memset(&header, 0, sizeof header);
	ssize_t bytes_read = TEMP_FAILURE_RETRY(read(fd, &header, sizeof header));
	if (bytes_read != (ssize_t) sizeof header) {
		close(fd);
		return -2;
	}

	if (strncmp(header.tzdata_version, "tzdata", 6) != 0 || header.tzdata_version[11] != 0) {
		close(fd);
		return -2;
	}

	if (TEMP_FAILURE_RETRY(lseek(fd, ntohl(header.index_offset), SEEK_SET)) == -1) {
		close(fd);
		return -2;
	}

	if (ntohl(header.index_offset) > ntohl(header.data_offset)) {
		close(fd);
		return -2;
	}

	const size_t index_size = ntohl(header.data_offset) - ntohl(header.index_offset);
	if ((index_size % sizeof(struct index_entry_t)) != 0) {
		close(fd);
		return -2;
	}

	char* index = malloc(index_size);
	if (index == NULL) {
		close(fd);
		return -2;
	}
	if (TEMP_FAILURE_RETRY(read(fd, index, index_size)) != (ssize_t) index_size) {
		free(index);
		close(fd);
		return -2;
	}

	off_t specific_zone_offset = -1;
	size_t id_count = index_size / sizeof(struct index_entry_t);
	for (size_t i = 0; i < id_count; ++i) {
		char this_id[NAME_LENGTH + 1];
		memcpy(this_id, index + (i * sizeof(struct index_entry_t)), NAME_LENGTH);
		this_id[NAME_LENGTH] = '\0';

		if (strcmp(this_id, olson_id) == 0) {
			const struct index_entry_t* entry = (const struct index_entry_t*) (index + (i * sizeof(struct index_entry_t)));
			specific_zone_offset = ntohl(entry->start) + ntohl(header.data_offset);
			*entry_length = ntohl(entry->length);
			break;
		}
	}
	free(index);

	if (specific_zone_offset == -1) {
		// We found a valid tzdata file, but didn't find the requested id in it.
		// Give up now, and don't try fallback tzdata files.
		close(fd);
		// Matches upstream expectations: no TZif file for the requested id.
		errno = ENOENT;
		return -1;
	}

	if (TEMP_FAILURE_RETRY(lseek(fd, specific_zone_offset, SEEK_SET)) == -1) {
		close(fd);
		return -2;
	}

	return fd;
}

int __bionic_open_tzdata(const char* olson_id, int32_t* entry_length) {
	int fd;

	// Try the two locations for the tzdata file in a strict order:
	// 1: The timezone data module which contains the main copy. This is the
	//    common case for current devices.
	// 2: The ultimate fallback: the non-updatable copy in /system.
	fd = __bionic_open_tzdata_path("/apex/com.android.tzdata/etc/tz/tzdata", olson_id, entry_length);
	if (fd >= -1) return fd;

	fd = __bionic_open_tzdata_path("/system/usr/share/zoneinfo/tzdata", olson_id, entry_length);
	if (fd >= -1) return fd;

	// Not finding any tzdata is more serious than not finding a specific zone.
	return fd;
}
