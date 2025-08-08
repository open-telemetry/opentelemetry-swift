//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class RegisteredReader: Equatable, Hashable {
  private(set) static var id_counter = OtelAtomicInt32(0)
    
  public let id: Int32
  public let reader: MetricReader
  public let registry: ViewRegistry
  public var lastCollectedEpochNanos: UInt64 = 0

  init(reader: MetricReader, registry: ViewRegistry) {
    self.id = Self.id_counter.increment()
    self.reader = reader
    self.registry = registry
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  public static func == (lhs: RegisteredReader, rhs: RegisteredReader) -> Bool {
    if lhs === rhs {
      return true
    }
    return lhs.id == rhs.id
  }
}
