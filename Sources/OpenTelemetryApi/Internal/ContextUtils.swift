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

/// Helper class to get the current Span and current distributedContext
/// Users must interact with the current Context via the public APIs in Tracer and avoid
/// accessing this class directly.
public struct ContextUtils {
    struct ContextEntry {
        var span: Span?
        var distContext: CorrelationContext?
    }

    static let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
    static let sym = dlsym(RTLD_DEFAULT, "_os_activity_current")
    static let OS_ACTIVITY_CURRENT = unsafeBitCast(sym, to: os_activity_t.self)

    static var contextMap = [os_activity_id_t: ContextEntry]()

    /// Returns the Span from the current context
    public static func getCurrentSpan() -> Span? {
        let activityIdent = os_activity_get_identifier(OS_ACTIVITY_CURRENT, nil)
        return contextMap[activityIdent]?.span
    }

    /// Returns the CorrelationContext from the current context
    public static func getCurrentCorrelationContext() -> CorrelationContext? {
        let activityIdent = os_activity_get_identifier(OS_ACTIVITY_CURRENT, nil)
        return contextMap[activityIdent]?.distContext
    }

    /// Returns a new Scope encapsulating the provided Span added to the current context
    /// - Parameter span: the Span to be added to the current context
    public static func withSpan(_ span: Span) -> Scope {
        return SpanInScope(span: span)
    }

    /// Returns a new Scope encapsulating the provided Correlation Context added to the current context
    /// - Parameter distContext: the Correlation Context to be added to the current contex
    public static func withCorrelationContext(_ distContext: CorrelationContext) -> Scope {
        return CorrelationContextInScope(distContext: distContext)
    }

    static func setContext(activityId: os_activity_id_t, forSpan span: Span) {
        if contextMap[activityId] != nil {
            contextMap[activityId]!.span = span
        } else {
            contextMap[activityId] = ContextEntry(span: span, distContext: getCurrentCorrelationContext())
        }
    }

    static func setContext(activityId: os_activity_id_t, forCorrelationContext distContext: CorrelationContext) {
        if contextMap[activityId] != nil {
            contextMap[activityId]!.distContext = distContext
        } else {
            contextMap[activityId] = ContextEntry(span: getCurrentSpan(), distContext: distContext)
        }
    }
}
