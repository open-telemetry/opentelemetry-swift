// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

/// Provides a framework for detection of resource information from the environment variable "OC_RESOURCE_LABELS".
public struct EnvVarResource {
    private static let otelResourceLabelsEnv = "OTEL_RESOURCE_LABELS"
    private static let labelListSplitter = Character(",")
    private static let labelKeyValueSplitter = Character("=")

    ///  This resource information is loaded from the OC_RESOURCE_LABELS
    ///  environment variable.
    public static let resource = Resource(labels: parseResourceLabels(rawEnvLabels: ProcessInfo.processInfo.environment[otelResourceLabelsEnv]))

    private init() {}

    /// Creates a label map from the OC_RESOURCE_LABELS environment variable.
    /// OC_RESOURCE_LABELS: A comma-separated list of labels describing the source in more detail,
    /// e.g. “key1=val1,key2=val2”. Domain names and paths are accepted as label keys. Values may be
    /// quoted or unquoted in general. If a value contains whitespaces, =, or " characters, it must
    /// always be quoted.
    /// - Parameter rawEnvLabels: the comma-separated list of labels
    private static func parseResourceLabels(rawEnvLabels: String?) -> [String: String] {
        guard let rawEnvLabels = rawEnvLabels else { return [String: String]() }

        var labels = [String: String]()

        rawEnvLabels.split(separator: labelListSplitter).forEach {
            let split = $0.split(separator: labelKeyValueSplitter)
            if split.count != 2 {
                return
            }
            let key = split[0].trimmingCharacters(in: .whitespaces)
            let value = split[1].trimmingCharacters(in: CharacterSet(charactersIn: "^\"|\"$"))
            labels[key] = value
        }
        return labels
    }
}
