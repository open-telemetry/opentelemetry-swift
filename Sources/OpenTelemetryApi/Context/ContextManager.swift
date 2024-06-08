/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol ContextManager: AnyObject {
    func getCurrentContextValue(forKey: OpenTelemetryContextKeys) -> AnyObject?
    func setCurrentContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject)
    func removeContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject)
    func withCurrentContextValue<T>(forKey: OpenTelemetryContextKeys, value: AnyObject?, _ operation: () throws -> T) rethrows -> T
#if canImport(_Concurrency)
    func withCurrentContextValue<T>(forKey: OpenTelemetryContextKeys, value: AnyObject?, _ operation: () async throws -> T) async rethrows -> T
#endif
}
