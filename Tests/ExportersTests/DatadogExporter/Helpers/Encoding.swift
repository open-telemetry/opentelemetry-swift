/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
@testable import DatadogExporter

extension EncodableValue: Equatable {
  public static func == (lhs: EncodableValue, rhs: EncodableValue) -> Bool {
    return String(describing: lhs) == String(describing: rhs)
  }
}

/// Prior to `iOS13.0`, the `JSONEncoder` supports only object or array as the root type.
/// Hence we can't test encoding `Encodable` values directly and we need as support of this `EncodingContainer` container.
///
/// Reference: https://bugs.swift.org/browse/SR-6163
struct EncodingContainer<Value: Encodable>: Encodable {
  let value: Value

  init(_ value: Value) {
    self.value = value
  }
}
