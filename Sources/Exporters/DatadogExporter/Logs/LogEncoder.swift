/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

internal struct LogAttributes {
    /// Log attributes received from the user. They are subject for sanitization.
    let userAttributes: [String: Encodable]
    /// Log attributes added internally by the SDK. They are not a subject for sanitization.
    let internalAttributes: [String: Encodable]?
}

/// `Encodable` representation of log. It gets sanitized before encoding.
internal struct DDLog: Encodable {
    internal struct TracingAttributes {
        static let traceID = "dd.trace_id"
        static let spanID = "dd.span_id"
    }

    enum Status: String, Encodable {
        case debug
        case info
        case notice
        case warn
        case error
        case critical
    }

    let date: Date
    let status: Status
    let message: String
    let serviceName: String
    let environment: String
    let loggerName: String
    let loggerVersion: String
    let threadName: String
    let applicationVersion: String
    let attributes: LogAttributes
    let tags: [String]?

    func encode(to encoder: Encoder) throws {
        let sanitizedLog = LogSanitizer().sanitize(log: self)
        try LogEncoder().encode(sanitizedLog, to: encoder)
    }

    internal init(date: Date, status: DDLog.Status, message: String, serviceName: String, environment: String, loggerName: String, loggerVersion: String, threadName: String, applicationVersion: String, attributes: LogAttributes, tags: [String]?) {
        self.date = date
        self.status = status
        self.message = message
        self.serviceName = serviceName
        self.environment = environment
        self.loggerName = loggerName
        self.loggerVersion = loggerVersion
        self.threadName = threadName
        self.applicationVersion = applicationVersion
        self.attributes = attributes
        self.tags = tags
    }

    internal init(event: SpanData.Event, span: SpanData, configuration: ExporterConfiguration) {
        var attributes = event.attributes

        // set tracing attributes
        let internalAttributes = [
            TracingAttributes.traceID: "\(span.traceId.rawLowerLong)",
            TracingAttributes.spanID: "\(span.spanId.rawValue)"
        ]

        self.date = event.timestamp
        self.status = Status(rawValue: event.attributes["status"]?.description ?? "info") ?? .info
        self.message = attributes.removeValue(forKey: "message")?.description ?? "Span event"
        self.serviceName = configuration.serviceName
        self.environment = configuration.environment
        self.loggerName = attributes.removeValue(forKey: "loggerName")?.description ?? "logger"
        self.loggerVersion = "1.0" // loggerVersion
        self.threadName = attributes.removeValue(forKey: "threadName")?.description ?? "unkown"
        self.applicationVersion = configuration.version

        let userAttributes:  [String: Encodable] = attributes.mapValues{
            switch $0 {
                case let .string(value):
                    return value
                case let .bool(value):
                    return value
                case let .int(value):
                    return value
                case let .double(value):
                    return value
                case let .stringArray(value):
                    return value
                case let .boolArray(value):
                    return value
                case let .intArray(value):
                    return value
                case let .doubleArray(value):
                    return value
            }
        }
        self.attributes = LogAttributes(userAttributes: userAttributes, internalAttributes: internalAttributes)
        self.tags = nil // tags
    }
}

/// Encodes `Log` to given encoder.
internal struct LogEncoder {
    /// Coding keys for permanent `Log` attributes.
    enum StaticCodingKeys: String, CodingKey {
        case date
        case status
        case message
        case serviceName = "service"
        case tags = "ddtags"

        // MARK: - Application info

        case applicationVersion = "version"

        // MARK: - Logger info

        case loggerName = "logger.name"
        case loggerVersion = "logger.version"
        case threadName = "logger.thread_name"
    }

    /// Coding keys for dynamic `Log` attributes specified by user.
    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
        init(_ string: String) { self.stringValue = string }
    }

    func encode(_ log: DDLog, to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StaticCodingKeys.self)
        try container.encode(log.date, forKey: .date)
        try container.encode(log.status, forKey: .status)
        try container.encode(log.message, forKey: .message)
        try container.encode(log.serviceName, forKey: .serviceName)

        // Encode logger info
        try container.encode(log.loggerName, forKey: .loggerName)
        try container.encode(log.loggerVersion, forKey: .loggerVersion)
        try container.encode(log.threadName, forKey: .threadName)

        // Encode application info
        try container.encode(log.applicationVersion, forKey: .applicationVersion)

        // Encode attributes...
        var attributesContainer = encoder.container(keyedBy: DynamicCodingKey.self)

        // ... first, user attributes ...
        let encodableUserAttributes = Dictionary(
            uniqueKeysWithValues: log.attributes.userAttributes.map { name, value in (name, EncodableValue(value)) }
        )
        try encodableUserAttributes.forEach { try attributesContainer.encode($0.value, forKey: DynamicCodingKey($0.key)) }

        // ... then, internal attributes:
        if let internalAttributes = log.attributes.internalAttributes {
            let encodableInternalAttributes = Dictionary(
                uniqueKeysWithValues: internalAttributes.map { name, value in (name, EncodableValue(value)) }
            )
            try encodableInternalAttributes.forEach { try attributesContainer.encode($0.value, forKey: DynamicCodingKey($0.key)) }
        }

        // Encode tags
        var tags = log.tags ?? []
        tags.append("env:\(log.environment)") // include default tag
        let tagsString = tags.joined(separator: ",")
        try container.encode(tagsString, forKey: .tags)
    }
}
