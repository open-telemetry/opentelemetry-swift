/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import Foundation

// MARK: - Log Mocks

extension DDLog {
    static func mockWith(
        date: Date = .mockAny(),
        status: DDLog.Status = .mockAny(),
        message: String = .mockAny(),
        serviceName: String = .mockAny(),
        environment: String = .mockAny(),
        loggerName: String = .mockAny(),
        loggerVersion: String = .mockAny(),
        threadName: String = .mockAny(),
        applicationVersion: String = .mockAny(),
        attributes: LogAttributes = .mockAny(),
        tags: [String]? = nil
    ) -> DDLog {
        return DDLog(
            date: date,
            status: status,
            message: message,
            serviceName: serviceName,
            environment: environment,
            loggerName: loggerName,
            loggerVersion: loggerVersion,
            threadName: threadName,
            applicationVersion: applicationVersion,
            attributes: attributes,
            tags: tags
        )
    }
}

extension DDLog.Status {
    static func mockAny() -> DDLog.Status {
        return .info
    }
}

extension LogAttributes: Equatable {
    static func mockAny() -> LogAttributes {
        return mockWith()
    }

    static func mockWith(
        userAttributes: [String: Encodable] = [:],
        internalAttributes: [String: Encodable]? = [:]
    ) -> LogAttributes {
        return LogAttributes(
            userAttributes: userAttributes,
            internalAttributes: internalAttributes
        )
    }

    public static func == (lhs: LogAttributes, rhs: LogAttributes) -> Bool {
        let lhsUserAttributesSorted = lhs.userAttributes.sorted { $0.key < $1.key }
        let rhsUserAttributesSorted = rhs.userAttributes.sorted { $0.key < $1.key }

        let lhsInternalAttributesSorted = lhs.internalAttributes?.sorted { $0.key < $1.key }
        let rhsInternalAttributesSorted = rhs.internalAttributes?.sorted { $0.key < $1.key }

        return String(describing: lhsUserAttributesSorted) == String(describing: rhsUserAttributesSorted)
            && String(describing: lhsInternalAttributesSorted) == String(describing: rhsInternalAttributesSorted)
    }
}
