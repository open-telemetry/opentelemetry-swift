/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

#if canImport(_Concurrency)
public class TaskLocalContextManager: ContextManager {
#if swift(>=5.9)
    package static let instance = TaskLocalContextManager()
#else
    static let instance = TaskLocalContextManager()
#endif

    @TaskLocal static var context = [String: AnyObject]()

    public func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject? {
        Self.context[key.rawValue]
    }
    
    public func setCurrentContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject) {}

    public func removeContextValue(forKey: OpenTelemetryContextKeys, value: AnyObject) {}

    public func withCurrentContextValue<T>(forKey key: OpenTelemetryContextKeys, value: AnyObject?, _ operation: () async throws -> T) async throws -> T {
        var context = Self.context
        context[key.rawValue] = value

        return try await Self.$context.withValue(context, operation: operation)
    }
}
#endif
