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
import ObjectiveC
import os.activity

// Bridging Obj-C variabled defined as c-macroses. See `activity.h` header.
private let OS_ACTIVITY_CURRENT = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_os_activity_current"),
                                                to: os_activity_t.self)
@_silgen_name("_os_activity_create") private func _os_activity_create(_ dso: UnsafeRawPointer?,
                                                                      _ description: UnsafePointer<Int8>,
                                                                      _ parent: Unmanaged<AnyObject>?,
                                                                      _ flags: os_activity_flag_t) -> AnyObject!

///  A class that manages the scope for a Span
class SpanInScope: Scope {
    var currentActivityState = os_activity_scope_state_s()
    var currentActivityId: os_activity_id_t

    /// Constructs a new SpanInScope.
    /// - Parameter span: the Span to be added to the current context
    init(span: Span) {
        let dso = UnsafeMutableRawPointer(mutating: #dsohandle)
        let activity = _os_activity_create(dso, "InitSpan", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
        currentActivityId = os_activity_get_identifier(activity, nil)
        os_activity_scope_enter(activity, &currentActivityState)
        ContextUtils.setContext(activityId: currentActivityId, forSpan: span)
        span.scope = self
    }

    func close() {
        os_activity_scope_leave(&currentActivityState)
        ContextUtils.removeContextForSpan(activityId: currentActivityId)
    }

    deinit {
        close()
    }
}
