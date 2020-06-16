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

struct TelemetryInfo {
    var tracer: Tracer
    var contextManager: CorrelationContextManager
    var propagators: ContextPropagators
    var emptyCorrelationContext: CorrelationContext
    var spanContextTable: SpanContextShimTable

    init(tracer: Tracer, contextManager: CorrelationContextManager, propagators: ContextPropagators) {
        self.tracer = tracer
        self.contextManager = contextManager
        self.propagators = propagators
        emptyCorrelationContext = contextManager.contextBuilder().build()
        spanContextTable = SpanContextShimTable()
    }
}
