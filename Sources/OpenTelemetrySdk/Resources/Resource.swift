/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

/// Resource represents a resource, which capture identifying information about the entities
/// for which signals (stats or traces) are reported.
public struct Resource: Equatable, Hashable, Codable {
    private static let maxLength = 255

    /// A dictionary of labels that describe the resource.
    public var attributes: [String: AttributeValue]

    ///  Returns a default Resource.
    public init() {
        let executableName = ProcessInfo.processInfo.processName
        self.init(attributes: [ResourceAttributes.serviceName.rawValue: AttributeValue.string("unknown_service:\(executableName)"),
                               ResourceAttributes.telemetrySdkName.rawValue: AttributeValue.string("opentelemetry"),
                               ResourceAttributes.telemetrySdkLanguage.rawValue: AttributeValue.string("swift"),
                               ResourceAttributes.telemetrySdkVersion.rawValue: AttributeValue.string(Resource.OTEL_SWIFT_SDK_VERSION)]
        )
    }

    ///  Returns an empty Resource.
    static var empty: Resource {
        return self.init(attributes: [String: AttributeValue]())
    }

    /// Returns a Resource.
    /// - Parameter labels: a dictionary of labels that describe the resource.
    public init(attributes: [String: AttributeValue]) {
        if Resource.checkAttributes(attributes: attributes) {
            self.attributes = attributes
        } else {
            self.attributes = [String: AttributeValue]()
        }
    }

    /// Modifies the current Resource by merging with the other Resource.
    /// In case of a collision, new Resource takes precedence.
    /// - Parameter other: the Resource that will be merged with this
    public mutating func merge(other: Resource) {
        attributes.merge(other.attributes) { _, other in other }
    }

    /// Returns a new, merged Resource by merging the current Resource with the other Resource.
    /// In case of a collision, new Resource takes precedence.
    /// - Parameter other: the Resource that will be merged with this
    public func merging(other: Resource) -> Resource {
        let labelsCopy = attributes.merging(other.attributes) { _, other in other }
        return Resource(attributes: labelsCopy)
    }

    private static func checkAttributes(attributes: [String: AttributeValue]) -> Bool {
        for entry in attributes {
            if !isValidAndNotEmpty(name: entry.key) {
                return false
            }
        }
        return true
    }

    /// Determines whether the given String is a valid printable ASCII string with a length not
    /// exceed 255 characters.
    /// - Parameter name: the name to be validated.
    private static func isValid(name: String) -> Bool {
        return name.count <= maxLength && StringUtils.isPrintableString(name)
    }

    /// ¡Determines whether the given String is a valid printable ASCII string with a length
    /// greater than 0 and not exceed 255 characters.
    /// - Parameter name: the name to be validated.
    private static func isValidAndNotEmpty(name: String) -> Bool {
        return !name.isEmpty && isValid(name: name)
    }
}
