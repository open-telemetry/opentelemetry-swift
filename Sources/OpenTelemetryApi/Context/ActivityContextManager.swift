/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import os.activity

// Bridging Obj-C variabled defined as c-macroses. See `activity.h` header.
private let OS_ACTIVITY_CURRENT = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_os_activity_current"),
                                                to: os_activity_t.self)
@_silgen_name("_os_activity_create") private func _os_activity_create(_ dso: UnsafeRawPointer?,
                                                                      _ description: UnsafePointer<Int8>,
                                                                      _ parent: Unmanaged<AnyObject>?,
                                                                      _ flags: os_activity_flag_t) -> AnyObject!

class ActivityContextManager: ContextManager {
    static let instance = ActivityContextManager()
#if canImport(_Concurrency)
#if swift(<5.5.2)
    @available(macOS 12.0, iOS 15.0, tvOS 15.0, *)
    static let taskLocalContextManager = TaskLocalContextManager.instance
#else
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, *)
    static let taskLocalContextManager = TaskLocalContextManager.instance
#endif
#endif

    let rlock = NSRecursiveLock()

    class ScopeElement {
        init(scope: os_activity_scope_state_s) {
            self.scope = scope
        }

        deinit {}

        var scope: os_activity_scope_state_s
    }

    var objectScope = NSMapTable<AnyObject, ScopeElement>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    var contextMap = [os_activity_id_t: [String: AnyObject]]()

    func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject? {
        var parentIdent: os_activity_id_t = 0
        let activityIdent = os_activity_get_identifier(OS_ACTIVITY_CURRENT, &parentIdent)
        var contextValue: AnyObject?
        if activityIdent != 0 {
            rlock.lock()
            guard let context = contextMap[activityIdent] ?? contextMap[parentIdent] else {
                rlock.unlock()
                return nil
            }
            contextValue = context[key.rawValue]
            rlock.unlock()
            return contextValue
        } else {
// If activityIdent == 0,  it means no active Span or we are inside an Task
#if canImport(_Concurrency)
#if swift(<5.5.2)
            if #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) {
                if let contextValue = ActivityContextManager.taskLocalContextManager.getCurrentContextValue(forKey: key) {
                    return contextValue
                }
            }
#else
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
                if let contextValue = ActivityContextManager.taskLocalContextManager.getCurrentContextValue(forKey: key) {
                    return contextValue
                }
            }
#endif
#endif
        }
        return nil
    }

    func setCurrentContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
        var parentIdent: os_activity_id_t = 0
        var activityIdent = os_activity_get_identifier(OS_ACTIVITY_CURRENT, &parentIdent)
        if activityIdent != 0 {
            // We are inside an activity, it can be an activity created by us for a span context or another independent activty
            // We are surely not inside a Task
            rlock.lock()
            if contextMap[activityIdent] == nil || contextMap[activityIdent]?[key.rawValue] != nil {
                var scope: os_activity_scope_state_s
                (activityIdent, scope) = createActivityContext()
                contextMap[activityIdent] = [String: AnyObject]()
                objectScope.setObject(ScopeElement(scope: scope), forKey: value)
            }
            contextMap[activityIdent]?[key.rawValue] = value
            rlock.unlock()
        } else {
            var scope: os_activity_scope_state_s
            (activityIdent, scope) = createActivityContext()
            if activityIdent == 0 {
// If activityIdent == 0, means we are inside a Task, because we cannot create an activity, set the context inside the task
#if canImport(_Concurrency)
#if swift(<5.5.2)
                if #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) {
                    ActivityContextManager.taskLocalContextManager.setCurrentContextValue(forKey: key, value: value)
                }
#else
                if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
                    ActivityContextManager.taskLocalContextManager.setCurrentContextValue(forKey: key, value: value)
                }

#endif
#endif
            } else {
                // We could create the activity so we store the context in the activity map
                rlock.lock()
                contextMap[activityIdent] = [String: AnyObject]()
                objectScope.setObject(ScopeElement(scope: scope), forKey: value)
                contextMap[activityIdent]?[key.rawValue] = value
                rlock.unlock()
            }
        }
    }

    func createActivityContext() -> (os_activity_id_t, os_activity_scope_state_s) {
        let dso = UnsafeMutableRawPointer(mutating: #dsohandle)
        let activity = _os_activity_create(dso, "ActivityContext", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
        let currentActivityId = os_activity_get_identifier(activity, nil)
        var activityState = os_activity_scope_state_s()
        os_activity_scope_enter(activity, &activityState)
        return (currentActivityId, activityState)
    }

    func removeContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
        if let scope = objectScope.object(forKey: value) {
            var scope = scope.scope
            os_activity_scope_leave(&scope)
            objectScope.removeObject(forKey: value)
        } else {
#if canImport(_Concurrency)
#if swift(<5.5.2)
            if #available(macOS 12.0, iOS 15.0, tvOS 15.0, *) {
                // If there is a parent activity, set its content as the task local
                ActivityContextManager.taskLocalContextManager.removeContextValue(forKey: key, value: value)
                if let currentContext = self.getCurrentContextValue(forKey: key) {
                    ActivityContextManager.taskLocalContextManager.setCurrentContextValue(forKey: key, value: currentContext)
                }
            }
#else
            // If there is a parent activity, set its content as the task local
            if #available(macOS 10.15, iOS 13.0, tvOS 13.0, *) {
                ActivityContextManager.taskLocalContextManager.removeContextValue(forKey: key, value: value)
                if let currentContext = self.getCurrentContextValue(forKey: key) {
                    ActivityContextManager.taskLocalContextManager.setCurrentContextValue(forKey: key, value: currentContext)
                }
            }
#endif
#endif
        }
    }
}
