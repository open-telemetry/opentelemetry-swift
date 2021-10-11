/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

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

    /// Either the API key or a regular client token
    /// For metrics reporting API key is needed
    var apiKey: String
    /// Endpoint that will be used for reporting.
    var endpoint: Endpoint
    /// Exporter will deflate payloads before sending
    var payloadCompression: Bool

    var source: String
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

    public init(serviceName: String, resource: String, applicationName: String, applicationVersion: String, environment: String, apiKey: String, endpoint: Endpoint, payloadCompression: Bool = true, source: String = "ios", uploadCondition: @escaping () -> Bool, performancePreset: PerformancePreset = .default, exportUnsampledSpans: Bool = true, exportUnsampledLogs: Bool = true, hostName: String? = nil, metricsNamePrefix: String? = "otel") {
        self.serviceName = serviceName
        self.resource = resource
        self.applicationName = applicationName
        self.version = applicationVersion
        self.environment = environment
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.payloadCompression = payloadCompression
        self.source = source
        self.uploadCondition = uploadCondition
        self.performancePreset = performancePreset
        self.exportUnsampledSpans = exportUnsampledSpans
        self.exportUnsampledLogs = exportUnsampledLogs
        self.hostName = hostName
        self.metricsNamePrefix = metricsNamePrefix
    }
}
