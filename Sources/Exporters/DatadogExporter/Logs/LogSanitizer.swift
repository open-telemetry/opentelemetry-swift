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

/// Sanitizes `Log` representation received from the user, so it can match Datadog log constraints.
internal struct LogSanitizer {
    struct Constraints {
        /// Attribute names reserved for Datadog.
        /// If any of those is used by the user, the attribute will be ignored.
        static let reservedAttributeNames: Set<String> = [
            "host", "message", "status", "service", "source", "error.message", "error.stack", "ddtags",
            DDLog.TracingAttributes.traceID,
            DDLog.TracingAttributes.spanID,
        ]
        /// Maximum number of nested levels in attribute name. E.g. `person.address.street` has 3 levels.
        /// If attribute name exceeds this number, extra levels are escaped by using `_` character (`one.two.(...).nine.ten_eleven_twelve`).
        static let maxNestedLevelsInAttributeName: Int = 9
        /// Maximum number of attributes in log.
        /// If this number is exceeded, extra attributes will be ignored.
        static let maxNumberOfAttributes: Int = 256
        /// Allowed first character of a tag name (given as ASCII values ranging from lowercased `a` to `z`) .
        /// Tags with name starting with different character will be dropped.
        static let allowedTagNameFirstCharacterASCIIRange: [UInt8] = Array(97...122)
        /// Maximum lenght of the tag.
        /// Tags exceeting this lenght will be trunkated.
        static let maxTagLength: Int = 200
        /// Tag keys reserved for Datadog.
        /// If any of those is used by user, the tag will be ignored.
        static let reservedTagKeys: Set<String> = [
            "host", "device", "source", "service", "env",
        ]
        /// Maximum number of attributes in log.
        /// If this number is exceeded, extra attributes will be ignored.
        static let maxNumberOfTags: Int = 100
    }

    func sanitize(log: DDLog) -> DDLog {
        return DDLog(
            date: log.date,
            status: log.status,
            message: log.message,
            serviceName: log.serviceName,
            environment: log.environment,
            loggerName: log.loggerName,
            loggerVersion: log.loggerVersion,
            threadName: log.threadName,
            applicationVersion: log.applicationVersion,
            attributes: sanitize(attributes: log.attributes),
            tags: sanitize(tags: log.tags)
        )
    }

    // MARK: - Attributes sanitization

    private func sanitize(attributes rawAttributes: LogAttributes) -> LogAttributes {
        // Sanitizes only `userAttributes`, `internalAttributes` remain untouched
        var userAttributes = rawAttributes.userAttributes
        userAttributes = removeInvalidAttributes(userAttributes)
        userAttributes = removeReservedAttributes(userAttributes)
        userAttributes = sanitizeAttributeNames(userAttributes)
        let userAttributesLimit = Constraints.maxNumberOfAttributes - (rawAttributes.internalAttributes?.count ?? 0)
        userAttributes = limitToMaxNumberOfAttributes(userAttributes, limit: userAttributesLimit)

        return LogAttributes(
            userAttributes: userAttributes,
            internalAttributes: rawAttributes.internalAttributes
        )
    }

    private func removeInvalidAttributes(_ attributes: [String: Encodable]) -> [String: Encodable] {
        // Attribute name cannot be empty
        return attributes.filter { attribute in
            if attribute.key.isEmpty {
                print("Attribute key is empty. This attribute will be ignored.")
                return false
            }
            return true
        }
    }

    private func removeReservedAttributes(_ attributes: [String: Encodable]) -> [String: Encodable] {
        return attributes.filter { attribute in
            if Constraints.reservedAttributeNames.contains(attribute.key) {
                return false
            }
            return true
        }
    }

    private func sanitizeAttributeNames(_ attributes: [String: Encodable]) -> [String: Encodable] {
        let sanitizedAttributes: [(String, Encodable)] = attributes.map { name, value in
            let sanitizedName = sanitize(attributeName: name)
            if sanitizedName != name {
                print("Attribute '\(name)' was modified to '\(sanitizedName)' to match Datadog constraints.")
                return (sanitizedName, value)
            } else {
                return (name, value)
            }
        }
        return Dictionary(uniqueKeysWithValues: sanitizedAttributes)
    }

    private func sanitize(attributeName: String) -> String {
        // Attribute name can only have `Constants.maxNestedLevelsInAttributeName` levels. Escape extra levels with "_".
        var dotsCount = 0
        var sanitized = ""
        for char in attributeName {
            if char == "." {
                dotsCount += 1
                sanitized.append(dotsCount > Constraints.maxNestedLevelsInAttributeName ? "_" : char)
            } else {
                sanitized.append(char)
            }
        }
        return sanitized
    }

    private func limitToMaxNumberOfAttributes(_ attributes: [String: Encodable], limit: Int) -> [String: Encodable] {
        // Only `limit` number of attributes are allowed.
        if attributes.count > limit {
            let extraAttributesCount = attributes.count - Constraints.maxNumberOfAttributes
            print("Number of attributes exceeds the limit of \(Constraints.maxNumberOfAttributes). \(extraAttributesCount) attribute(s) will be ignored.")
            return Dictionary(uniqueKeysWithValues: attributes.dropLast(extraAttributesCount))
        } else {
            return attributes
        }
    }

    // MARK: - Tags sanitization

    private func sanitize(tags rawTags: [String]?) -> [String]? {
        if let rawTags = rawTags {
            let tags = rawTags
                .map { $0.lowercased() }
                .filter { startsWithAllowedCharacter(tag: $0) }
                .map { replaceIllegalCharactersIn(tag: $0) }
                .map { removeTrailingCommasIn(tag: $0) }
                .map { limitToMaxLength(tag: $0) }
                .filter { isNotReserved(tag: $0) }
            return limitToMaxNumberOfTags(tags)
        } else {
            return nil
        }
    }

    private func startsWithAllowedCharacter(tag: String) -> Bool {
        guard let firstCharacter = tag.first?.asciiValue else {
            print("Tag is empty and will be ignored.")
            return false
        }

        // Tag must start with a letter
        if Constraints.allowedTagNameFirstCharacterASCIIRange.contains(firstCharacter) {
            return true
        } else {
            print("Tag '\(tag)' starts with an invalid character and will be ignored.")
            return false
        }
    }

    private func replaceIllegalCharactersIn(tag: String) -> String {
        let sanitized = tag.replacingOccurrences(of: #"[^a-z0-9_:.\/-]"#, with: "_", options: .regularExpression)
        if sanitized != tag {
            print("Tag '\(tag)' was modified to '\(sanitized)' to match Datadog constraints.")
        }
        return sanitized
    }

    private func removeTrailingCommasIn(tag: String) -> String {
        // If present, remove trailing commas `:`
        var sanitized = tag
        while sanitized.last == ":" { _ = sanitized.removeLast() }
        if sanitized != tag {
            print("Tag '\(tag)' was modified to '\(sanitized)' to match Datadog constraints.")
        }
        return sanitized
    }

    private func limitToMaxLength(tag: String) -> String {
        if tag.count > Constraints.maxTagLength {
            let sanitized = String(tag.prefix(Constraints.maxTagLength))
            print("Tag '\(tag)' was modified to '\(sanitized)' to match Datadog constraints.")
            return sanitized
        } else {
            return tag
        }
    }

    private func isNotReserved(tag: String) -> Bool {
        if let colonIndex = tag.firstIndex(of: ":") {
            let key = String(tag.prefix(upTo: colonIndex))
            if Constraints.reservedTagKeys.contains(key) {
                print("'\(key)' is a reserved tag key. This tag will be ignored.")
                return false
            } else {
                return true
            }
        } else {
            return true
        }
    }

    private func limitToMaxNumberOfTags(_ tags: [String]) -> [String] {
        // Only `Constraints.maxNumberOfTags` of tags are allowed.
        if tags.count > Constraints.maxNumberOfTags {
            let extraTagsCount = tags.count - Constraints.maxNumberOfTags
            print("Number of tags exceeds the limit of \(Constraints.maxNumberOfTags). \(extraTagsCount) attribute(s) will be ignored.")
            return tags.dropLast(extraTagsCount)
        } else {
            return tags
        }
    }
}
