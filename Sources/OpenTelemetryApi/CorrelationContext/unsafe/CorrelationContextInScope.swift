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

///  A scope that manages the context for a CorrelationContext.
class CorrelationContextInScope: Scope {
    var current = os_activity_scope_state_s()

    /// Constructs a new CorrelationContextInScope.
    /// - Parameter distContext: the CorrelationContext to be added to the current context.
    init(distContext: CorrelationContext) {
        let dso = UnsafeMutableRawPointer(mutating: #dsohandle)
        let activity = _os_activity_create(dso, "InitSpan", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
        let activityId = os_activity_get_identifier(activity, nil)
        os_activity_scope_enter(activity, &current)
        ContextUtils.setContext(activityId: activityId, forCorrelationContext: distContext)
    }

    func close() {
        os_activity_scope_leave(&current)
    }

    deinit {
        close()
    }
}
