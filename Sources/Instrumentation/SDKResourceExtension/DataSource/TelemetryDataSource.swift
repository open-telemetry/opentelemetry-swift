/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public class TelemetryDataSource: ITelemetryDataSource {
    public var language: String {
        ResourceAttributes.TelemetrySdkLanguageValues.swift.description
    }

    public var name: String {
        "opentelemetry"
    }

    public var version: String? {
        // This may not work if this agent is statically built
        Bundle(for: type(of: self)).infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
