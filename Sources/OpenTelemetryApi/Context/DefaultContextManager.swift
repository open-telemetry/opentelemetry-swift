//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

/// A no-op context manager
class DefaultContextManager: ContextManager {
    func getCurrentContextValue(forKey key: OpenTelemetryContextKeys) -> AnyObject? {
        nil
    }

    func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () throws -> T) rethrows -> T {
        return try action()
    }

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func withActiveContext<T>(key: OpenTelemetryContextKeys, value: AnyObject, _ action: () async throws -> T) async rethrows -> T {
        return try await action()
    }
}


extension OpenTelemetryContextProvider {
    /// Use the no-op context manager. Context will *not* work properly if this manager is used.
    public static var defaultManager: Self {
        .init(contextManager: DefaultContextManager())
    }
}
