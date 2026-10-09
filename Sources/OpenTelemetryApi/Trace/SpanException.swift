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
    let error = self as Error
    let errorType = Swift.type(of: error) == NSError.self
      ? domain
      : String(reflecting: Swift.type(of: error))

    // Manually supplied domains matching the runtime-context pattern are normalized too.
    return errorType
      .replacingOccurrences(
        of: #"\(unknown context at \$[0-9a-fA-F]+\)\."#,
        with: "",
        options: .regularExpression
      )
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
