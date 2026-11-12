/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#include "LaunchEnvironment.h"

#include <TargetConditionals.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

#if TARGET_OS_IOS || TARGET_OS_VISION
  #include <mach/mach.h>
#endif

static bool isActivePrewarm = false;
static bool isBackgroundLaunch = false;
static double initializerTime = 0;

#if !TARGET_OS_WATCH
// Like Datadog, reads the role the system gave the process when it started it. Only roles that
// say the app isn't in the foreground count, so a role that's unknown or can't be read doesn't
// turn a launch the user waited for into a background launch.
static bool readIsBackgroundRole(void) {
#if TARGET_OS_IOS || TARGET_OS_VISION
  task_category_policy_data_t policy;
  mach_msg_type_number_t count = TASK_CATEGORY_POLICY_COUNT;
  boolean_t getDefault = FALSE;
  if (task_policy_get(mach_task_self(), TASK_CATEGORY_POLICY, (task_policy_t)&policy, &count, &getDefault) != KERN_SUCCESS
      || getDefault) {
    return false;
  }
  switch (policy.role) {
  case TASK_BACKGROUND_APPLICATION:
  case TASK_DARWINBG_APPLICATION:
  case TASK_NONUI_APPLICATION:
    return true;
  default:
    return false;
  }
#else
  return false;
#endif
}

__attribute__((constructor)) static void otel_app_launch_read_launch_environment(void) {
  struct timeval now;
  gettimeofday(&now, NULL);
  initializerTime = (double)now.tv_sec + (double)now.tv_usec / 1e6;

  const char *activePrewarm = getenv("ActivePrewarm");
  isActivePrewarm = activePrewarm != NULL && strcmp(activePrewarm, "1") == 0;
  // A prewarmed process isn't in the foreground either, but the user launches it.
  isBackgroundLaunch = !isActivePrewarm && readIsBackgroundRole();
}
#endif

bool otel_app_launch_is_active_prewarm(void) {
  return isActivePrewarm;
}

bool otel_app_launch_is_background_launch(void) {
  return isBackgroundLaunch;
}

double otel_app_launch_initializer_time(void) {
  return initializerTime;
}
