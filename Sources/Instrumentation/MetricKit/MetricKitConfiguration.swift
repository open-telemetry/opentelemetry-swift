/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(MetricKit) && !os(tvOS) && !os(macOS)
    import Foundation
    import MetricKit
    import OpenTelemetryApi

    @available(iOS 13.0, macOS 12.0, macCatalyst 13.1, visionOS 1.0, *)
    public struct MetricKitConfiguration {
        public init(
            useAppleStacktraceFormat: Bool = false,
            tracer: Tracer? = nil
        ) {
            self.useAppleStacktraceFormat = useAppleStacktraceFormat
            self.tracer = tracer ??
                OpenTelemetry.instance.tracerProvider.get(
                    instrumentationName: "MetricKit",
                    instrumentationVersion: "0.0.1"
                )
        }

        /// The tracer to use for creating spans from MetricKit payloads.
        public var tracer: Tracer

        /// When true, stacktraces from crash and hang diagnostics will be reported in Apple's
        /// native MetricKit JSON format instead of being transformed to the simplified OpenTelemetry format.
        ///
        /// Default: false (stacktraces are transformed to OTel format)
        public var useAppleStacktraceFormat: Bool
    }
#endif
