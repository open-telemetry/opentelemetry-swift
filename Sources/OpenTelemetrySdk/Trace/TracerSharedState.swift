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

/// Represents the shared state/config between all Tracers created by the same TracerRegistry.
public class TracerSharedState {
    public private(set) var clock: Clock
    public private(set) var idsGenerator: IdsGenerator
    public private(set) var resource: Resource

    public private(set) var activeTraceConfig = TraceConfig()
    public private(set) var activeSpanProcessor: SpanProcessor = NoopSpanProcessor()
    public private(set) var isStopped = false

    private var registeredSpanProcessors = [SpanProcessor]()

    public init(clock: Clock, idsGenerator: IdsGenerator, resource: Resource) {
        self.clock = clock
        self.idsGenerator = idsGenerator
        self.resource = resource
    }

    /// Adds a new SpanProcessor
    /// - Parameter spanProcessor:  the new SpanProcessor to be added.
    public func addSpanProcessor(_ spanProcessor: SpanProcessor) {
        registeredSpanProcessors.append(spanProcessor)
        activeSpanProcessor = MultiSpanProcessor(spanProcessors: registeredSpanProcessors)
    }

    /// Stops tracing, including shutting down processors and set to true isStopped.
    public func stop() {
        if isStopped {
            return
        }
        activeSpanProcessor.shutdown()
        isStopped = true
    }

    internal func setActiveTraceConfig(_ activeTraceConfig: TraceConfig) {
        self.activeTraceConfig = activeTraceConfig
    }
}
