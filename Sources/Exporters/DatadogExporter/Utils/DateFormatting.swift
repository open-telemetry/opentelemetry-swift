/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

internal protocol DateFormatterType {
    func string(from date: Date) -> String
}

extension ISO8601DateFormatter: DateFormatterType {}
extension DateFormatter: DateFormatterType {}

/// Date formatter producing `ISO8601` string representation of a given date.
/// Should be used to encode dates in messages send to the server.
internal let iso8601DateFormatter: DateFormatterType = {
    // As there is a known crash in iOS 11.0 and 11.1 when using `.withFractionalSeconds` option in `ISO8601DateFormatter`,
    // we use different `DateFormatterType` implementation depending on the OS version. The problem was fixed by Apple in iOS 11.2.
    if #available(iOS 11.2, macOS 10.13, tvOS 11.2, *) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)
        return formatter
    } else {
        let iso8601Formatter = DateFormatter()
        iso8601Formatter.locale = Locale(identifier: "en_US_POSIX")
        iso8601Formatter.timeZone = TimeZone(abbreviation: "UTC")! // swiftlint:disable:this force_unwrapping
        iso8601Formatter.calendar = Calendar(identifier: .gregorian)
        iso8601Formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'" // ISO8601 format
        return iso8601Formatter
    }
}()
