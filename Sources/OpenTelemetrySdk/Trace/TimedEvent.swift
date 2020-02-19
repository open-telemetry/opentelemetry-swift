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
import OpenTelemetryApi

/// Timed event.
public struct TimedEvent: Equatable {
    public private(set) var epochNanos: Int
    public private(set) var name: String
    public private(set) var attributes: [String: AttributeValue]

    /// Creates an TimedEvent with the given time, name and empty attributes.
    /// - Parameters:
    ///   - nanotime: epoch timestamp in nanos.
    ///   - name: the name of this TimedEvent.
    ///   - attributes: the attributes of this TimedEvent. Empty by default.
    public init(nanotime: Int, name: String, attributes: [String: AttributeValue] = [String: AttributeValue]()) {
        epochNanos = nanotime
        self.name = name
        self.attributes = attributes
    }

    /// Creates an TimedEvent with the given time and event.
    /// - Parameters:
    ///   - nanotime: epoch timestamp in nanos.
    ///   - event: the event.
    public init(nanotime: Int, event: Event) {
        self.init(nanotime: nanotime, name: event.name, attributes: event.attributes)
    }
}
