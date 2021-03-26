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

/// Represents the shared state/config between all Tracers created by the same TracerProvider.
class TracerSharedState {
    var clock: Clock
    var idGenerator: IdGenerator
    var resource: Resource

    var sampler: Sampler = ParentBasedSampler(root: Samplers.alwaysOn)
    var activeSpanLimits = SpanLimits()
    var activeSpanProcessor: SpanProcessor = NoopSpanProcessor()
    var hasBeenShutdown = false

    var registeredSpanProcessors = [SpanProcessor]()

    init(clock: Clock, idGenerator: IdGenerator, resource: Resource) {
        self.clock = clock
        self.idGenerator = idGenerator
        self.resource = resource
    }

    /// Adds a new SpanProcessor
    /// - Parameter spanProcessor:  the new SpanProcessor to be added.
    func addSpanProcessor(_ spanProcessor: SpanProcessor) {
        registeredSpanProcessors.append(spanProcessor)
        activeSpanProcessor = MultiSpanProcessor(spanProcessors: registeredSpanProcessors)
    }

    /// Stops tracing, including shutting down processors and set to true isStopped.
    func stop() {
        if hasBeenShutdown {
            return
        }
        activeSpanProcessor.shutdown()
        hasBeenShutdown = true
    }

    func setActiveSpanLimits(_ activeSpanLimits: SpanLimits) {
        self.activeSpanLimits = activeSpanLimits
    }

    func setSampler(_ sampler: Sampler) {
        self.sampler = sampler
    }

    // Sets the global sampler probability
    func setSamplerProbability(samplerProbability: Double) {
        if samplerProbability >= 1 {
            return setSampler(Samplers.alwaysOn)
        } else if samplerProbability <= 0 {
            return setSampler(Samplers.alwaysOff)
        } else {
            return setSampler(Samplers.traceIdRatio(ratio: samplerProbability))
        }
    }
}
