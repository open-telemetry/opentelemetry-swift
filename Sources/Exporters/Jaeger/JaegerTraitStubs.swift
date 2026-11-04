/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !Jaeger && !os(watchOS) && !os(visionOS)

  @available(*, unavailable, message: "JaegerExporter requires the `Jaeger` package trait.")
  public final class JaegerSpanExporter {}

#endif
