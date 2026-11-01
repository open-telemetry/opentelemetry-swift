/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef OTEL_APP_LAUNCH_PAGE_SAMPLING_H
#define OTEL_APP_LAUNCH_PAGE_SAMPLING_H

#include <stdbool.h>

/// Samples the same pages of the app's code as this module's initializer did before `main()`.
/// `residentAtEnd` is how many are in memory now, and `pagedIn` how many of those weren't then.
/// Returns `false` if the pages can't be read, or on watchOS, where nothing is sampled.
bool otel_app_launch_read_page_sample(int *residentAtEnd, int *pagedIn);

/// The process's page-ins before this module's initializer ran, and since. Returns `false` if they
/// can't be read, or on watchOS, where nothing is sampled.
bool otel_app_launch_read_page_ins(int *preInitializer, int *postInitializer);

#endif
