/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if !SwiftObservabilityAPIBridges

  import OpenTelemetryApi

  @available(*, unavailable, message: "OTelSwiftLog requires the `SwiftObservabilityAPIBridges` package trait.")
  public struct OTelLogHandler {
    public init(loggerProvider: LoggerProvider = OpenTelemetry.instance.loggerProvider,
                includeTraceContext: Bool = true,
                attributes: [String: AttributeValue] = [String: AttributeValue]()) {}
  }

#endif
