/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !OpenTracing

  @available(*, unavailable, message: "OpenTracingShim-experimental requires the `OpenTracing` package trait.")
  public final class TraceShim {}

#endif
