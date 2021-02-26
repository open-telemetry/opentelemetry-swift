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

/// Struct that holds global trace parameters.
public struct SpanLimits: Equatable {
    // These values are the default values for all the global parameters.
    // TODO: decide which default sampler to use

    /// The global default max number of attributes perSpan.
    public private(set) var attributeCountLimit: Int = 128
     ///  the global default max number of Events per Span.
    public private(set) var eventCountLimit: Int = 128
     /// the global default max number of Link entries per Span.
    public private(set) var linkCountLimit: Int = 128
     /// the global default max number of attributes per Event.
    public private(set) var attributePerEventCountLimit: Int = 128
    /// the global default max number of attributes per Link.
    public private(set) var attributePerLinkCountLimit: Int = 128
    /// Returns the defaultSpanLimits.
    public init() {}

    @discardableResult public func settingAttributeCountLimit(_ number: UInt) -> Self {
        var spanLimits = self
        spanLimits.attributeCountLimit = number > 0 ? Int(number) : 0
        return spanLimits
    }

    @discardableResult public func settingEventCountLimit(_ number: UInt) -> Self {
        var spanLimits = self
        spanLimits.eventCountLimit = number > 0 ? Int(number) : 0
        return spanLimits
    }

    @discardableResult public func settingLinkCountLimit(_ number: UInt) -> Self {
        var spanLimits = self
        spanLimits.linkCountLimit = number > 0 ? Int(number) : 0
        return spanLimits
    }

    @discardableResult public func settingAttributePerEventCountLimit(_ number: UInt) -> Self {
        var spanLimits = self
        spanLimits.attributePerEventCountLimit = number > 0 ? Int(number) : 0
        return spanLimits
    }

    @discardableResult public func settingAttributePerLinkCountLimit(_ number: UInt) -> Self {
        var spanLimits = self
        spanLimits.attributePerLinkCountLimit = number > 0 ? Int(number) : 0
        return spanLimits
    }

    public static func == (lhs: SpanLimits, rhs: SpanLimits) -> Bool {
        return lhs.attributeCountLimit == rhs.attributeCountLimit &&
            lhs.eventCountLimit == rhs.eventCountLimit &&
            lhs.linkCountLimit == rhs.linkCountLimit &&
            lhs.attributePerEventCountLimit == rhs.attributePerEventCountLimit &&
            lhs.attributePerLinkCountLimit == rhs.attributePerLinkCountLimit
    }
}
