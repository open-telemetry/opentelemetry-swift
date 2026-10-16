//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
#if !canImport(Darwin)
  import Atomics
#endif

public class RegisteredReader: Equatable, Hashable {
  #if canImport(Darwin)
    private(set) nonisolated(unsafe) static var id_counter: Int32 = 0
  #else
    private(set) nonisolated(unsafe) static var id_counter = ManagedAtomic<Int32>(0)
  #endif

  public let id: Int32
  public let reader: MetricReader
  public let registry: ViewRegistry
  public var lastCollectedEpochNanos: UInt64 = 0

  init(reader: MetricReader, registry: ViewRegistry) {
    #if canImport(Darwin)
      id = OSAtomicIncrement32(&Self.id_counter)
    #else
      id = Self.id_counter.wrappingIncrementThenLoad(ordering: .relaxed)
    #endif

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
