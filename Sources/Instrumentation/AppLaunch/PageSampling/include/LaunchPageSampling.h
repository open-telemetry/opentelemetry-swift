/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef OTEL_APP_LAUNCH_PAGE_SAMPLING_H
#define OTEL_APP_LAUNCH_PAGE_SAMPLING_H

#include <stdbool.h>

/// Samples the same pages of the app's code as this module's initializer did before `main()`.
/// `sampled` is how many pages that is, `residentAtEnd` how many are in memory now, and `pagedIn`
/// how many of those weren't then. Returns `false` if the pages can't be read, or on watchOS, where
/// nothing is sampled.
bool otel_app_launch_read_page_sample(int *sampled, int *residentAtEnd, int *pagedIn);

/// Records whether the same pages this module's initializer sampled are in memory now, as the
/// baseline for a resume. Call it when the app enters the background, which is off the path the
/// resume is measured on. Each call replaces the previous baseline. Returns `false` if the pages
/// can't be read, or on watchOS, where nothing is sampled.
bool otel_app_launch_sample_pages_at_background(void);

/// Compares the sampled pages with the baseline `otel_app_launch_sample_pages_at_background` took,
/// so `pagedIn` is how many of the app's sampled pages came back since it entered the background.
/// Returns `false` if there's no such baseline, which is the case for a resume the app didn't enter
/// the background before, or if the pages can't be read.
bool otel_app_launch_read_background_page_sample(int *sampled, int *residentAtEnd, int *pagedIn);

/// The process's page-ins before this module's initializer ran, and since. Returns `false` if they
/// can't be read, or on watchOS, where nothing is sampled.
bool otel_app_launch_read_page_ins(int *preInitializer, int *postInitializer);

/// The process's page-ins so far, for measuring a window that this module didn't bound, such as a
/// resume. Returns `false` if they can't be read, or on watchOS, where nothing is sampled.
bool otel_app_launch_read_page_ins_now(int *pageIns);

#endif
