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
public struct TraceConfig: Equatable {
    // These values are the default values for all the global parameters.
    // TODO: decide which default sampler to use

    /// Returns the global default Sampler which is used when constructing a new Span
    var sampler: Sampler = Samplers.alwaysOn

    /// The global default max number of attributes perSpan.
    var maxNumberOfAttributes: Int = 32 {
        didSet {
            maxNumberOfAttributes < 0 ? maxNumberOfAttributes = 0 : Void()
        }
    }

    ///  the global default max number of Events per Span.
    var maxNumberOfEvents: Int = 128 {
        didSet {
            maxNumberOfEvents < 0 ? maxNumberOfEvents = 0 : Void()
        }
    }

    /// the global default max number of Link entries per Span.
    var maxNumberOfLinks: Int = 32 {
        didSet {
            maxNumberOfLinks < 0 ? maxNumberOfLinks = 0 : Void()
        }
    }

    /// the global default max number of attributes per Event.
    var maxNumberOfAttributesPerEvent: Int = 32 {
        didSet {
            maxNumberOfAttributesPerEvent < 0 ? maxNumberOfAttributesPerEvent = 0 : Void()
        }
    }

    /// the global default max number of attributes per Link.
    var maxNumberOfAttributesPerLink: Int = 32 {
        didSet {
            maxNumberOfAttributesPerLink < 0 ? maxNumberOfAttributesPerLink = 0 : Void()
        }
    }

    /// Returns the defaultTraceConfig.
    public init() {
    }

    public func settingSampler(_ sampler: Sampler) -> Self {
        var traceConfig = self
        traceConfig.sampler = sampler
        return traceConfig
    }

    public func settingMaxNumberOfAttributes(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfAttributes = number
        return traceConfig
    }

    public func settingMaxNumberOfEvents(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfEvents = number
        return traceConfig
    }

    public func settingMaxNumberOfLinks(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfLinks = number
        return traceConfig
    }

    public func settingMaxNumberOfAttributesPerEvent(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfAttributesPerEvent = number
        return traceConfig
    }

    public func settingMaxNumberOfAttributesPerLink(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfAttributesPerLink = number
        return traceConfig
    }

    public static func == (lhs: TraceConfig, rhs: TraceConfig) -> Bool {
        return lhs.sampler === rhs.sampler &&
            lhs.maxNumberOfAttributes == rhs.maxNumberOfAttributes &&
            lhs.maxNumberOfEvents == rhs.maxNumberOfEvents &&
            lhs.maxNumberOfLinks == rhs.maxNumberOfLinks &&
            lhs.maxNumberOfAttributesPerEvent == rhs.maxNumberOfAttributesPerEvent &&
            lhs.maxNumberOfAttributesPerLink == rhs.maxNumberOfAttributesPerLink
    }
}
