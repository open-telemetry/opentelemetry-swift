/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

#if canImport(os.activity)
  @preconcurrency import os.activity

  // Bridging Obj-C variabled defined as c-macroses. See `activity.h` header.
  // swiftlint:disable identifier_name
  nonisolated(unsafe) private let OS_ACTIVITY_CURRENT = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_os_activity_current"),
                                                  to: os_activity_t.self)
  // swiftlint:enable identifier_name
  @_silgen_name("_os_activity_create") private func _os_activity_create(
    _ dso: UnsafeRawPointer?,
    _ description: UnsafePointer<Int8>,
    _ parent: Unmanaged<AnyObject>?,
    _ flags: os_activity_flag_t
  ) -> AnyObject!

  public final class ActivityContextManager: ImperativeContextManager, @unchecked Sendable {
    static let instance = ActivityContextManager()

    let rlock = NSRecursiveLock()

    class ScopeElement {
      init(scope: os_activity_scope_state_s) {
        self.scope = scope
      }

      var scope: os_activity_scope_state_s
    }

    var objectScope = NSMapTable<AnyObject, ScopeElement>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    var contextMap = [os_activity_id_t: [String: AnyObject]]()

    public func getCurrentContextValue(forKey key: OpenTelemetryContextKeys)
      -> AnyObject? {
      var parentIdent: os_activity_id_t = 0
      let activityIdent = os_activity_get_identifier(OS_ACTIVITY_CURRENT, &parentIdent)
      var contextValue: AnyObject?
      rlock.lock()
      guard let context = contextMap[activityIdent] ?? contextMap[parentIdent]
      else {
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
      if contextMap[activityIdent] == nil
        || contextMap[activityIdent]?[key.rawValue] != nil {
        var scope: os_activity_scope_state_s
        (activityIdent, scope) = createActivityContext()
        contextMap[activityIdent] = [String: AnyObject]()
        objectScope.setObject(ScopeElement(scope: scope), forKey: value)
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

      for (activityKey, activity) in contextMap
        where value === activity[key.rawValue] {
        contextMap[activityKey]?[key.rawValue] = nil
        if contextMap[activityKey]?.isEmpty ?? false {
          contextMap[activityKey] = nil
        }
      }
      if let scope = objectScope.object(forKey: value) {
        var scope = scope.scope
        os_activity_scope_leave(&scope)
        objectScope.removeObject(forKey: value)
      }
      rlock.unlock()
    }
  }
#endif
