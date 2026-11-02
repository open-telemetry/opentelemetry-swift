/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#include "LaunchPageSampling.h"

#include <TargetConditionals.h>

#if !TARGET_OS_WATCH
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
// The same pages' residency when the app last entered the background, for measuring a resume.
static bool wasResidentAtBackground[MAX_SAMPLED_PAGES];
static bool hasBackgroundSample = false;
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

// Inserted libraries come before the executable in dyld's image list, so it isn't always image 0.
static const char *mainExecutablePath(void) {
  uint32_t imageCount = _dyld_image_count();
  for (uint32_t image = 0; image < imageCount; image++) {
    const struct mach_header *header = _dyld_get_image_header(image);
    if (header != NULL && header->filetype == MH_EXECUTE) {
      return _dyld_get_image_name(image);
    }
  }
  return NULL;
}

// The app's code can be in its main executable, its frameworks or in a debug build a `.debug.dylib`,
// so every image under its bundle counts. An executable outside a bundle has only its directory.
// The trailing separator keeps a sibling directory with the same prefix from matching.
static bool appImageRoot(const char **root, size_t *length) {
  const char *executable = mainExecutablePath();
  if (executable == NULL) {
    return false;
  }
  const char *bundle = strstr(executable, ".app/");
  const char *separator = bundle != NULL ? bundle + strlen(".app") : strrchr(executable, '/');
  if (separator == NULL) {
    return false;
  }
  *root = executable;
  *length = (size_t)(separator - executable) + 1;
  return true;
}

static bool appImageText(uint32_t image, const char *root, size_t rootLength, uintptr_t *start, uint64_t *size) {
  const char *name = _dyld_get_image_name(image);
  return name != NULL && strncmp(name, root, rootLength) == 0 && textSegment(image, start, size);
}

// The first page holds the headers dyld just read, so it says nothing about the launch.
static uint64_t samplablePages(uint64_t size, uint64_t pageSize) {
  uint64_t pageCount = size / pageSize;
  return pageCount > 1 ? pageCount - 1 : 0;
}

__attribute__((constructor)) static void otel_app_launch_sample_pages_at_start(void) {
  pageInsAtInitializer = readPageIns();
  const char *root = NULL;
  size_t rootLength = 0;
  if (!appImageRoot(&root, &rootLength)) {
    return;
  }
  uint64_t pageSize = (uint64_t)getpagesize();
  uint32_t imageCount = _dyld_image_count();
  uint64_t candidates = 0;
  for (uint32_t image = 0; image < imageCount; image++) {
    uintptr_t start = 0;
    uint64_t size = 0;
    if (appImageText(image, root, rootLength, &start, &size)) {
      candidates += samplablePages(size, pageSize);
    }
  }
  if (candidates == 0) {
    return;
  }
  int count = candidates < MAX_SAMPLED_PAGES ? (int)candidates : MAX_SAMPLED_PAGES;
  int next = 0;
  uint64_t imageOffset = 0;
  for (uint32_t image = 0; image < imageCount && next < count; image++) {
    uintptr_t start = 0;
    uint64_t size = 0;
    if (!appImageText(image, root, rootLength, &start, &size)) {
      continue;
    }
    uint64_t imagePages = samplablePages(size, pageSize);
    while (next < count) {
      uint64_t candidate = (uint64_t)next * candidates / (uint64_t)count;
      if (candidate >= imageOffset + imagePages) {
        break;
      }
      uintptr_t page = start + (uintptr_t)((1 + candidate - imageOffset) * pageSize);
      bool resident = false;
      if (!isResident(page, &resident)) {
        return;
      }
      sampledPages[next] = page;
      wasResident[next] = resident;
      next++;
    }
    imageOffset += imagePages;
  }
  sampledPageCount = next;
}

// `pagedIn` counts pages in memory now that weren't in `baseline`, so the caller's choice of
// baseline decides which window is measured.
static bool readSampleAgainst(const bool *baseline, int *sampled, int *residentAtEnd, int *pagedIn) {
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
      if (!baseline[i]) {
        pagedInCount++;
      }
    }
  }
  *sampled = sampledPageCount;
  *residentAtEnd = resident;
  *pagedIn = pagedInCount;
  return true;
}

bool otel_app_launch_read_page_sample(int *sampled, int *residentAtEnd, int *pagedIn) {
  return readSampleAgainst(wasResident, sampled, residentAtEnd, pagedIn);
}

bool otel_app_launch_sample_pages_at_background(void) {
  if (sampledPageCount == 0) {
    return false;
  }
  for (int i = 0; i < sampledPageCount; i++) {
    bool resident = false;
    if (!isResident(sampledPages[i], &resident)) {
      // A half-written baseline would undercount, so there's no baseline rather than a wrong one.
      hasBackgroundSample = false;
      return false;
    }
    wasResidentAtBackground[i] = resident;
  }
  hasBackgroundSample = true;
  return true;
}

bool otel_app_launch_read_background_page_sample(int *sampled, int *residentAtEnd, int *pagedIn) {
  if (!hasBackgroundSample) {
    return false;
  }
  return readSampleAgainst(wasResidentAtBackground, sampled, residentAtEnd, pagedIn);
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

bool otel_app_launch_read_page_ins_now(int *pageIns) {
  int now = readPageIns();
  if (now < 0) {
    return false;
  }
  *pageIns = now;
  return true;
}
#else
bool otel_app_launch_read_page_sample(int *sampled, int *residentAtEnd, int *pagedIn) {
  return false;
}

bool otel_app_launch_sample_pages_at_background(void) {
  return false;
}

bool otel_app_launch_read_background_page_sample(int *sampled, int *residentAtEnd, int *pagedIn) {
  return false;
}

bool otel_app_launch_read_page_ins(int *preInitializer, int *postInitializer) {
  return false;
}

bool otel_app_launch_read_page_ins_now(int *pageIns) {
  return false;
}
#endif
