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

struct SwiftErrorAdapter: SpanException {
  let error: Error

  var type: String {
    if Swift.type(of: error) is NSError.Type {
      return (error as NSError).type
    }

    return String(reflecting: Swift.type(of: error))
      .replacingOccurrences(
        of: #"\(unknown context at \$[0-9a-fA-F]+\)\."#,
        with: "",
        options: .regularExpression
      )
  }

  var message: String? {
    error.localizedDescription
  }

  var stackTrace: [String]? {
    nil
  }
}

extension NSError: SpanException {
  public var type: String {
    "\(domain) (\(code))"
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
