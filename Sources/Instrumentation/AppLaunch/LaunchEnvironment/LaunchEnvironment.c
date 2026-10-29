/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#include "LaunchEnvironment.h"

#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

static bool isActivePrewarm = false;
static double initializerTime = 0;

__attribute__((constructor)) static void otel_app_launch_read_launch_environment(void) {
  struct timeval now;
  gettimeofday(&now, NULL);
  initializerTime = (double)now.tv_sec + (double)now.tv_usec / 1e6;

  const char *activePrewarm = getenv("ActivePrewarm");
  isActivePrewarm = activePrewarm != NULL && strcmp(activePrewarm, "1") == 0;
}

bool otel_app_launch_is_active_prewarm(void) {
  return isActivePrewarm;
}

double otel_app_launch_initializer_time(void) {
  return initializerTime;
}
