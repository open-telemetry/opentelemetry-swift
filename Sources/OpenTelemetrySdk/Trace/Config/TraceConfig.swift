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
    public private(set) var sampler: Sampler = Samplers.alwaysOn

    /// The global default max number of attributes perSpan.
    public private(set) var maxNumberOfAttributes: Int = 1000 {
        didSet {
            maxNumberOfAttributes < 0 ? maxNumberOfAttributes = 0 : Void()
        }
    }

    ///  the global default max number of Events per Span.
    public private(set) var maxNumberOfEvents: Int = 1000 {
        didSet {
            maxNumberOfEvents < 0 ? maxNumberOfEvents = 0 : Void()
        }
    }

    /// the global default max number of Link entries per Span.
    public private(set) var maxNumberOfLinks: Int = 1000 {
        didSet {
            maxNumberOfLinks < 0 ? maxNumberOfLinks = 0 : Void()
        }
    }

    /// the global default max number of attributes per Event.
    public private(set) var maxNumberOfAttributesPerEvent: Int = 32 {
        didSet {
            maxNumberOfAttributesPerEvent < 0 ? maxNumberOfAttributesPerEvent = 0 : Void()
        }
    }

    /// the global default max number of attributes per Link.
    public private(set) var maxNumberOfAttributesPerLink: Int = 32 {
        didSet {
            maxNumberOfAttributesPerLink < 0 ? maxNumberOfAttributesPerLink = 0 : Void()
        }
    }

    /// Returns the defaultTraceConfig.
    public init() {
    }

    @discardableResult public func settingSampler(_ sampler: Sampler) -> Self {
        var traceConfig = self
        traceConfig.sampler = sampler
        return traceConfig
    }

    @discardableResult public func settingMaxNumberOfAttributes(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfAttributes = number
        return traceConfig
    }

    @discardableResult public func settingMaxNumberOfEvents(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfEvents = number
        return traceConfig
    }

    @discardableResult public func settingMaxNumberOfLinks(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfLinks = number
        return traceConfig
    }

    @discardableResult public func settingMaxNumberOfAttributesPerEvent(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfAttributesPerEvent = number
        return traceConfig
    }

    @discardableResult public func settingMaxNumberOfAttributesPerLink(_ number: Int) -> Self {
        var traceConfig = self
        traceConfig.maxNumberOfAttributesPerLink = number
        return traceConfig
    }

    // Sets the global sampler probability
    @discardableResult public func settingSamplerProbability(samplerProbability: Double) -> Self {
        if samplerProbability >= 1 {
            return settingSampler(Samplers.alwaysOn)
        } else if samplerProbability <= 0 {
            return settingSampler(Samplers.alwaysOff)
        } else {
            return settingSampler(Samplers.probability(probability: samplerProbability))
        }
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
