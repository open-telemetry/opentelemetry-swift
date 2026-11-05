/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef OTEL_APP_LAUNCH_LAUNCH_ENVIRONMENT_H
#define OTEL_APP_LAUNCH_LAUNCH_ENVIRONMENT_H

#include <stdbool.h>

/// Whether the system prewarmed this process, read from the `ActivePrewarm` environment variable
/// before `main()`, because `UIApplication` removes it during launch.
bool otel_app_launch_is_active_prewarm(void);

/// Whether the system started this process in the background, for example for a background fetch
/// or a silent push, rather than for the user or a prewarm. Always `false` on macOS, tvOS and
/// watchOS.
bool otel_app_launch_is_background_launch(void);

/// When this module's initializer ran before `main()`, in seconds since 1970, or 0 if it hasn't run.
double otel_app_launch_initializer_time(void);

#endif
