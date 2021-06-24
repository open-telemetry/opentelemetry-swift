/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Provides a framework for detection of resource information from the environment variable
public struct EnvVarHeaders {
    private static let otelAttributesEnv = "OTEL_EXPORTER_OTLP_HEADERS"
    private static let labelListSplitter = Character(",")
    private static let labelKeyValueSplitter = Character("=")

    ///  This resource information is loaded from the 
    ///  environment variable.
    public static let attributes : [(String,String)]? = parseAttributes(rawEnvAttributes: ProcessInfo.processInfo.environment[otelAttributesEnv])

    private init() {}

    /// Creates a label map from the environment variable string.
    /// - Parameter rawEnvLabels: the comma-separated list of labels
    private static func parseAttributes(rawEnvAttributes: String?) -> [(String, String)]? {
        guard let rawEnvLabels = rawEnvAttributes else { return nil }

        var labels = [(String, String)]()

        rawEnvLabels.split(separator: labelListSplitter).forEach {
            let split = $0.split(separator: labelKeyValueSplitter)
            if split.count != 2 {
                return
            }
            let key = split[0].trimmingCharacters(in: .whitespaces)
            let value = split[1].trimmingCharacters(in: CharacterSet(charactersIn: "^\"|\"$"))
            labels.append((key,value))
        }
        return labels
    }
}
