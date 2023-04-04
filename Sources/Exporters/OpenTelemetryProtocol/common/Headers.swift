//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public struct Headers {
    // GetUserAgentHeader returns an OTLP header value of the form "OTel OTLP Exporter Swift/{{ .Version }}"
    // https://github.com/open-telemetry/opentelemetry-specification/blob/main/specification/protocol/exporter.md#user-agent
    public static func getUserAgentHeader() -> String {
        let version = OpenTelemetry.version
        let userAgent = "OTel-OTLP-Exporter-Swift/\(version)"

        return userAgent
    }
}
