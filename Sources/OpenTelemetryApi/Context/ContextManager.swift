/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// A basic context manager which may only be able to make a value active for the duration of a closure call. Managers which can support arbitrarily setting and getting context values should also conform to ``ManualContextManager``
public protocol ContextManager: AnyObject {
    func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject?
    
    @discardableResult
    func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () throws -> T) rethrows -> T

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    @discardableResult
    func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () async throws -> T) async rethrows -> T
}

/// A context manager which does not require the scoping of a closure to set new context values. These managers are more flexible, but may also require specific platform support.
public protocol ManualContextManager: ContextManager {
    func setCurrentContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject)
    func removeContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject)
}
