/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct OtlpConfiguration {
    public static let DefaultTimeoutInterval : TimeInterval = TimeInterval(10)


    /*
     * This is a first pass addition to satisfy the OTLP Configuration specification:
     * https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/exporter.md
     * It's possible to satisfy a few of these configuration options through the configuration of the GRPC channel
     * It's worth considering re-factoring the initialization of the OTLP exporters to collect all the configuration
     * in one locations.
     *
     * I've left several of the configuration options stubbed in comments, so that may be implemented in the future.
     */
    // let endpoint : URL? = URL(string: "https://localhost:4317")
    // let certificateFile
    // let compression
    public let headers : [(String,String)]?
    public let timeout : TimeInterval

    public init(timeout : TimeInterval  = OtlpConfiguration.DefaultTimeoutInterval, headers: [(String,String)]? = nil) {
        self.headers = headers
        self.timeout = timeout
    }
}
