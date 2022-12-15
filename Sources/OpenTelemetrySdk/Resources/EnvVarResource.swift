/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Provides a framework for detection of resource information from the environment variable "OC_RESOURCE_LABELS".
public struct EnvVarResource {
    private static let otelResourceAttributesEnv = "OTEL_RESOURCE_ATTRIBUTES"
    private static let labelListSplitter = Character(",")
    private static let labelKeyValueSplitter = Character("=")

    ///  This resource information is loaded from the OC_RESOURCE_LABELS
    ///  environment variable or from the Info.plist file of the application loading the framework.
    public static let resource = Resource().merging(other: Resource(attributes: parseResourceAttributes(rawEnvAttributes: ProcessInfo.processInfo.environment[otelResourceAttributesEnv])))
    private init() {}

    public static func get(environment: [String: String] = ProcessInfo.processInfo.environment) -> Resource {
        let attributesToRead = environment[otelResourceAttributesEnv] ??
            Bundle.main.infoDictionary?[otelResourceAttributesEnv] as? String

        return Resource().merging(other: Resource(attributes: parseResourceAttributes(rawEnvAttributes: attributesToRead)))
    }

    /// Creates a label map from the OC_RESOURCE_LABELS environment variable.
    /// OC_RESOURCE_LABELS: A comma-separated list of labels describing the source in more detail,
    /// e.g. “key1=val1,key2=val2”. Domain names and paths are accepted as label keys. Values may be
    /// quoted or unquoted in general. If a value contains whitespaces, =, or " characters, it must
    /// always be quoted.
    /// - Parameter rawEnvLabels: the comma-separated list of labels
    private static func parseResourceAttributes(rawEnvAttributes: String?) -> [String: AttributeValue] {
        guard let rawEnvLabels = rawEnvAttributes else { return [String: AttributeValue]() }

        var labels = [String: AttributeValue]()

        rawEnvLabels.split(separator: labelListSplitter).forEach {
            let split = $0.split(separator: labelKeyValueSplitter)
            if split.count != 2 {
                return
            }
            let key = split[0].trimmingCharacters(in: .whitespaces)
            let value = AttributeValue.string(split[1].trimmingCharacters(in: CharacterSet(charactersIn: "^\"|\"$")))
            labels[key] = value
        }
        return labels
    }
}
