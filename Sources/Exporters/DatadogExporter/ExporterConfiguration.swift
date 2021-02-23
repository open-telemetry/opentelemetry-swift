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

internal struct ExporterError: Error, CustomStringConvertible {
    let description: String
}

public struct ExporterConfiguration {
    /// The name of the service, resource, version,... that will be reported to the backend.
    var serviceName: String
    var resource: String
    var applicationName: String 
    var version: String
    var environment: String

    /// Either the RUM client token (which supports RUM, Logging and APM) or regular client token, only for Logging and APM.
    var clientToken: String?
    /// The api key, needed for metrics reporting
    var apiKey: String?
    /// Endpoint that will be used for reporting.
    var endpoint: Endpoint
    /// This conditon will be evaluated before trying to upload data
    /// Can be used to avoid reporting when no connection
    var uploadCondition: () -> Bool
    /// Performance preset for reporting
    var performancePreset: PerformancePreset
    /// Option to export spans that have TraceFlag off, true by default
    var exportUnsampledSpans: Bool
    /// Option to export logs from spans that have TraceFlag off, true by default
    var exportUnsampledLogs: Bool
    /// Option to add a host name to all the metrics sent by the exporter
    var hostName: String?
    /// Option to add a custom prefix to all the metrics sent by the exporter
    var metricsNamePrefix: String?

    public init(serviceName: String, resource: String, applicationName: String, applicationVersion: String, environment: String, clientToken: String?, apiKey: String?, endpoint: Endpoint, uploadCondition: @escaping () -> Bool, performancePreset: PerformancePreset = .default, exportUnsampledSpans: Bool = true, exportUnsampledLogs: Bool = true, hostName: String? = nil, metricsNamePrefix: String? = "otel") {
        self.serviceName = serviceName
        self.resource = resource
        self.applicationName = applicationName
        self.version = applicationVersion
        self.environment = environment
        self.clientToken = clientToken
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.uploadCondition = uploadCondition
        self.performancePreset = performancePreset
        self.exportUnsampledSpans = exportUnsampledSpans
        self.exportUnsampledLogs = exportUnsampledLogs
        self.hostName = hostName
        self.metricsNamePrefix = metricsNamePrefix
    }
}
