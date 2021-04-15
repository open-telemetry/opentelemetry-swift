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
import os.activity

/// Keys used by Opentelemetry to store values in the Context
internal struct OpenTelemetryContextKeys {
    static let span = "opentelemetrycontext.span"
    static let baggage    = "opentelemetrycontext.baggage"
}


public struct OpenTelemetryContextProvider {

    var contextManager: ContextManager


    /// Returns the Span from the current context
    public var activeSpan: Span? {
        return contextManager.getCurrentContextValue(forKey: OpenTelemetryContextKeys.span) as? Span
    }

    /// Returns the Baggage from the current context
    public var activeBaggage: Baggage? {
        return contextManager.getCurrentContextValue(forKey: OpenTelemetryContextKeys.baggage) as? Baggage
    }

    /// Sets the span as the activeSpan for the current context
    /// - Parameter span: the Span to be set to the current context
    public func setActiveSpan(_ span: Span)  {
        contextManager.setCurrentContextValue(forKey: OpenTelemetryContextKeys.span, value: span)
    }

    /// Sets the span as the activeSpan for the current context
    /// - Parameter baggage: the Correlation Context to be set to the current contex
    public func setActiveBaggage(_ baggage: Baggage) {
        contextManager.setCurrentContextValue(forKey: OpenTelemetryContextKeys.baggage, value: baggage)
    }

    public func removeContextForSpan(_ span: Span) {
        contextManager.removeContextValue(forKey: OpenTelemetryContextKeys.span, value: span)
    }

    public func removeContextForBaggage(_ baggage: Baggage) {
        contextManager.removeContextValue(forKey: OpenTelemetryContextKeys.baggage, value: baggage)
    }
}
