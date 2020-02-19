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

/// Struct to access a set of pre-defined Samplers.
public struct Samplers {
    /// A Sampler that always makes a "yes" decision on Span sampling.
    public static var alwaysOn: Sampler = AlwaysOnSampler()
    ///  Sampler that always makes a "no" decision on Span sampling.
    public static var alwaysOff: Sampler = AlwaysOffSampler()
    /// Returns a new Probability Sampler. The probability of sampling a trace is equal to that
    /// of the specified probability.
    /// - Parameter probability: The desired probability of sampling. Must be within [0.0, 1.0].
    public static func probability(probability: Double) -> Sampler {
        return Probability(probability: probability)
    }

    static var alwaysOnDecision: Decision = SimpleDecision(decision: true)
    static var alwaysOffDecision: Decision = SimpleDecision(decision: false)
}

class AlwaysOnSampler: Sampler {
    func shouldSample(parentContext: SpanContext?,
                      traceId: TraceId,
                      spanId: SpanId,
                      name: String,
                      parentLinks: [Link]) -> Decision {
        return Samplers.alwaysOnDecision
    }

    var description: String {
        return String(describing: AlwaysOnSampler.self)
    }
}

class AlwaysOffSampler: Sampler {
    func shouldSample(parentContext: SpanContext?,
                      traceId: TraceId,
                      spanId: SpanId,
                      name: String,
                      parentLinks: [Link]) -> Decision {
        return Samplers.alwaysOffDecision
    }

    var description: String {
        return String(describing: AlwaysOffSampler.self)
    }
}

/// We assume the lower 64 bits of the traceId's are randomly distributed around the whole (long)
/// range. We convert an incoming probability into an upper bound on that value, such that we can
/// just compare the absolute value of the id and the bound to see if we are within the desired
/// probability range. Using the low bits of the traceId also ensures that systems that only use 64
/// bit ID's will also work with this sampler.
class Probability: Sampler {
    var probability: Double
    var idUpperBound: UInt

    init(probability: Double) {
        self.probability = probability
        if probability <= 0.0 {
            idUpperBound = UInt.min
        } else if probability >= 1.0 {
            idUpperBound = UInt.max
        } else {
            idUpperBound = UInt(probability * Double(UInt.max))
        }
    }

    func shouldSample(parentContext: SpanContext?,
                      traceId: TraceId,
                      spanId: SpanId,
                      name: String,
                      parentLinks: [Link]) -> Decision {
        /// If the parent is sampled keep the sampling decision.
        if parentContext?.traceFlags.sampled ?? false {
            return Samplers.alwaysOnDecision
        }

        for link in parentLinks {
            /// If any parent link is sampled keep the sampling decision.
            if link.context.traceFlags.sampled {
                return Samplers.alwaysOnDecision
            }
        }
        /// Always sample if we are within probability range. This is true even for child spans (that
        /// may have had a different sampling decision made) to allow for different sampling policies,
        /// and dynamic increases to sampling probabilities for debugging purposes.
        /// Note use of `<` for comparison. This ensures that we never sample for probability == 0.0
        /// while allowing for a (very) small chance of *not* sampling if the id == Long.MAX_VALUE.
        /// This is considered a reasonable tradeoff for the simplicity/performance requirements (this
        /// code is executed in-line for every Span creation).
        if traceId.lowerLong < idUpperBound {
            return Samplers.alwaysOnDecision
        } else {
            return Samplers.alwaysOffDecision
        }
    }

    var description: String {
        return String(format: "ProbabilitySampler{%.6f}", probability)
    }
}

/// Sampling decision without attributes.
private struct SimpleDecision: Decision {
    let decision: Bool

    /// Creates sampling decision without attributes.
    /// - Parameter decision: sampling decision
    init(decision: Bool) {
        self.decision = decision
    }

    public var isSampled: Bool {
        return decision
    }

    public var attributes: [String: AttributeValue] {
        return [String: AttributeValue]()
    }
}
