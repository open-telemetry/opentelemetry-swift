/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol Logger {
  @available(*, deprecated, message: "Use logRecordBuilder() and setEventName(_:) instead")
  func eventBuilder(name: String) -> EventBuilder
  func logRecordBuilder() -> LogRecordBuilder
}
