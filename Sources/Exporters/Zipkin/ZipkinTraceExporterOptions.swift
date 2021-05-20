/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct ZipkinTraceExporterOptions {
    let endpoint: String
    let timeoutSeconds: TimeInterval
    let serviceName: String
    let useShortTraceIds: Bool
    let additionalHeaders: [String:String]

    public init(endpoint: String = "http://localhost:9411/api/v2/spans",
                serviceName: String = "Open Telemetry Exporter",
                timeoutSeconds: TimeInterval = 10.0,
                useShortTraceIds: Bool = false,
                additionalHeaders: [String:String] = [String:String]()) {

        self.endpoint = endpoint
        self.serviceName = serviceName
        self.timeoutSeconds = timeoutSeconds
        self.useShortTraceIds = useShortTraceIds
        self.additionalHeaders = additionalHeaders
    }
}

