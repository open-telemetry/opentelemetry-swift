/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#include "LaunchPageSampling.h"

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH
  #include <libgen.h>
  #include <limits.h>
  #include <mach-o/dyld.h>
  #include <mach-o/loader.h>
  #include <mach/mach.h>
  #include <stdint.h>
  #include <string.h>
  #include <sys/mman.h>
  #include <unistd.h>

  #define MAX_SAMPLED_PAGES 256

// Fixed size because this runs before `main()`, and the bound means a sample can't overflow.
static uintptr_t sampledPages[MAX_SAMPLED_PAGES];
static bool wasResident[MAX_SAMPLED_PAGES];
static int sampledPageCount = 0;
static int pageInsAtInitializer = -1;

static int readPageIns(void) {
  task_events_info_data_t info;
  mach_msg_type_number_t count = TASK_EVENTS_INFO_COUNT;
  if (task_info(mach_task_self(), TASK_EVENTS_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) {
    return -1;
  }
  return info.pageins;
}

static bool isResident(uintptr_t page, bool *resident) {
  char status = 0;
  if (mincore((const void *)page, 1, &status) != 0) {
    return false;
  }
  *resident = (status & MINCORE_INCORE) != 0;
  return true;
}

static bool textSegment(uint32_t image, uintptr_t *start, uint64_t *size) {
  const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(image);
  if (header == NULL || header->magic != MH_MAGIC_64) {
    return false;
  }
  const struct load_command *command = (const struct load_command *)(header + 1);
  for (uint32_t i = 0; i < header->ncmds; i++) {
    if (command->cmd == LC_SEGMENT_64) {
      const struct segment_command_64 *segment = (const struct segment_command_64 *)command;
      if (strncmp(segment->segname, SEG_TEXT, sizeof(segment->segname)) == 0) {
        *start = (uintptr_t)header;
        *size = segment->vmsize;
        return true;
      }
    }
    command = (const struct load_command *)((const char *)command + command->cmdsize);
  }
  return false;
}

// The app's code is in its main executable, a framework, or in a debug build a `.debug.dylib` next
// to the executable, so this takes the largest image in the executable's directory.
static bool largestAppImageText(uintptr_t *start, uint64_t *size) {
  const char *executable = _dyld_get_image_name(0);
  if (executable == NULL || strlen(executable) >= PATH_MAX) {
    return false;
  }
  char buffer[PATH_MAX];
  strcpy(buffer, executable);
  const char *directory = dirname(buffer);
  if (directory == NULL) {
    return false;
  }
  size_t directoryLength = strlen(directory);

  bool found = false;
  uint32_t imageCount = _dyld_image_count();
  for (uint32_t image = 0; image < imageCount; image++) {
    const char *name = _dyld_get_image_name(image);
    if (name == NULL || strncmp(name, directory, directoryLength) != 0) {
      continue;
    }
    uintptr_t imageStart = 0;
    uint64_t imageSize = 0;
    if (textSegment(image, &imageStart, &imageSize) && (!found || imageSize > *size)) {
      *start = imageStart;
      *size = imageSize;
      found = true;
    }
  }
  return found;
}

__attribute__((constructor)) static void otel_app_launch_sample_pages_at_start(void) {
  pageInsAtInitializer = readPageIns();
  uintptr_t start = 0;
  uint64_t size = 0;
  if (!largestAppImageText(&start, &size)) {
    return;
  }
  uint64_t pageSize = (uint64_t)getpagesize();
  // The first page holds the headers dyld just read, so it says nothing about the launch.
  uint64_t pageCount = size / pageSize;
  if (pageCount < 2) {
    return;
  }
  uint64_t candidates = pageCount - 1;
  int count = candidates < MAX_SAMPLED_PAGES ? (int)candidates : MAX_SAMPLED_PAGES;
  for (int i = 0; i < count; i++) {
    uintptr_t page = start + (uintptr_t)((1 + (uint64_t)i * candidates / (uint64_t)count) * pageSize);
    bool resident = false;
    if (!isResident(page, &resident)) {
      sampledPageCount = 0;
      return;
    }
    sampledPages[i] = page;
    wasResident[i] = resident;
  }
  sampledPageCount = count;
}

bool otel_app_launch_read_page_sample(int *residentAtEnd, int *pagedIn) {
  if (sampledPageCount == 0) {
    return false;
  }
  int resident = 0;
  int pagedInCount = 0;
  for (int i = 0; i < sampledPageCount; i++) {
    bool isInMemory = false;
    if (!isResident(sampledPages[i], &isInMemory)) {
      return false;
    }
    if (isInMemory) {
      resident++;
      if (!wasResident[i]) {
        pagedInCount++;
      }
    }
  }
  *residentAtEnd = resident;
  *pagedIn = pagedInCount;
  return true;
}

bool otel_app_launch_read_page_ins(int *preInitializer, int *postInitializer) {
  int pageIns = readPageIns();
  if (pageInsAtInitializer < 0 || pageIns < pageInsAtInitializer) {
    return false;
  }
  *preInitializer = pageInsAtInitializer;
  *postInitializer = pageIns - pageInsAtInitializer;
  return true;
}
#else
bool otel_app_launch_read_page_sample(int *residentAtEnd, int *pagedIn) {
  return false;
}

bool otel_app_launch_read_page_ins(int *preInitializer, int *postInitializer) {
  return false;
}
#endif
