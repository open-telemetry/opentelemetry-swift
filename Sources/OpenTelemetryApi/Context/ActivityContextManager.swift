/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
#if canImport(os.activity)
import os.activity

// Bridging Obj-C variabled defined as c-macroses. See `activity.h` header.
private let OS_ACTIVITY_CURRENT = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_os_activity_current"),
                                                to: os_activity_t.self)
@_silgen_name("_os_activity_create") private func _os_activity_create(_ dso: UnsafeRawPointer?,
                                                                      _ description: UnsafePointer<Int8>,
                                                                      _ parent: Unmanaged<AnyObject>?,
                                                                      _ flags: os_activity_flag_t) -> AnyObject!

public class ActivityContextManager: ManualContextManager {
    public static let instance = ActivityContextManager()

    let rlock = NSRecursiveLock()

    class ScopeElement {
        init(scope: os_activity_scope_state_s, identifier: os_activity_id_t) {
            self.scope = scope
            self.identifier = identifier
        }

        var scope: os_activity_scope_state_s
        var identifier: os_activity_id_t
    }

    var objectScope = NSMapTable<AnyObject, ScopeElement>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    var contextMap = [os_activity_id_t: [String: AnyObject]]()

    public func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject? {
        var parentIdent: os_activity_id_t = 0
        let activityIdent = os_activity_get_identifier(OS_ACTIVITY_CURRENT, &parentIdent)
        var contextValue: AnyObject?
        rlock.lock()
        guard let context = contextMap[activityIdent] ?? contextMap[parentIdent] else {
            rlock.unlock()
            return nil
        }
        contextValue = context[key.rawValue]
        rlock.unlock()
        return contextValue
    }

    public func setCurrentContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
        var parentIdent: os_activity_id_t = 0
        var activityIdent = os_activity_get_identifier(OS_ACTIVITY_CURRENT, &parentIdent)
        rlock.lock()
        if contextMap[activityIdent] == nil || contextMap[activityIdent]?[key.rawValue] != nil {
            var scope: os_activity_scope_state_s
            (activityIdent, scope) = createActivityContext()
            contextMap[activityIdent] = [String: AnyObject]()
            objectScope.setObject(ScopeElement(scope: scope, identifier: activityIdent), forKey: value)
        }
        contextMap[activityIdent]?[key.rawValue] = value
        rlock.unlock()
    }

    func createActivityContext() -> (os_activity_id_t, os_activity_scope_state_s) {
        let dso = UnsafeMutableRawPointer(mutating: #dsohandle)
        let activity = _os_activity_create(dso, "ActivityContext", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
        let currentActivityId = os_activity_get_identifier(activity, nil)
        var activityState = os_activity_scope_state_s()
        os_activity_scope_enter(activity, &activityState)
        return (currentActivityId, activityState)
    }

    public func removeContextValue(forKey key: OpenTelemetryContextKeys, value: AnyObject) {
        rlock.lock()
        defer {
            rlock.unlock()
        }

        guard let scope = objectScope.object(forKey: value) else {
            return
        }

        contextMap[scope.identifier]?[key.rawValue] = nil
        if contextMap[scope.identifier]?.isEmpty ?? false {
            contextMap[scope.identifier] = nil
        }

        os_activity_scope_leave(&scope.scope)
        objectScope.removeObject(forKey: value)
    }

    public func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () throws -> T) rethrows -> T {
        self.setCurrentContextValue(forKey: key, value: value)
        defer {
            self.removeContextValue(forKey: key, value: value)
        }

        return try action()
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () async throws -> T) async rethrows -> T {
        self.setCurrentContextValue(forKey: key, value: value)
        defer {
            self.removeContextValue(forKey: key, value: value)
        }

        return try await action()
    }
}
#endif
