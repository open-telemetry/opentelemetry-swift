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
