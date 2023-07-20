//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

/// A no-op context manager
public class DefaultContextManager: ContextManager {
    public func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject? {
        nil
    }

    public func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () throws -> T) rethrows -> T {
        return try action()
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () async throws -> T) async rethrows -> T {
        return try await action()
    }
}
