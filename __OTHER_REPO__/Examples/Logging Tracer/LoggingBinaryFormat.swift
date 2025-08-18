/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

struct LoggingBinaryFormat: BinaryFormattable {
  func fromByteArray(bytes: [UInt8]) -> SpanContext? {
    Logger.log("LoggingBinaryFormat.FromByteArray(...)")
    return nil
  }

  func toByteArray(spanContext: SpanContext) -> [UInt8] {
    Logger.log("LoggingBinaryFormat.ToByteArray({spanContext})")
    return [UInt8]()
  }
}
