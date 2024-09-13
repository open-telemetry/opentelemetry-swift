/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// An interface that represents an exception that can be attached to a span.
public protocol SpanException {
    var type: String { get }
    var message: String? { get }
    var stackTrace: [String]? { get }
}

extension NSError: SpanException {
    public var type: String {
        String(reflecting: self)
    }

    public var message: String? {
        localizedDescription
    }

    public var stackTrace: [String]? {
        nil
    }
}

#if !os(Linux)
extension NSException: SpanException {
    public var type: String {
        name.rawValue
    }

    public var message: String? {
        reason
    }

    public var stackTrace: [String]? {
        callStackSymbols
    }
}
#endif
