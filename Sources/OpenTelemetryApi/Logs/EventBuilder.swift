/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Used to construct and emit events from a Logger.
///
/// An event is a LogRecord with attributes for `event.domain` and `event.name`.
///
/// Obtain an Logger.eventBuilder(name: String), add properties using the stters, and emit
/// the LogRecord by calling `emit()`
public protocol EventBuilder: LogRecordBuilder {
  func setData(_ attributes: [String: AttributeValue]) -> Self
}

public extension EventBuilder {
  func setData(_ attributes: [String: AttributeValue]) -> Self {
    return self
  }
}
