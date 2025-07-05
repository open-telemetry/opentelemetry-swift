//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class MetricStorageRegistry {
  private var lock = Lock()
  private var registry = [MetricDescriptor: MetricStorage]()

  func getStorages() -> [MetricStorage] {
    lock.lock()
    defer {
      lock.unlock()
    }
    return Array(registry.values)
  }

  func register(newStorage: any MetricStorage) -> MetricStorage {
    let descriptor = newStorage.metricDescriptor
    lock.lock()
    defer {
      lock.unlock()
    }
    guard let storage = registry[descriptor] else {
      registry[descriptor] = newStorage

      return newStorage
    }

    for storage in registry.values {
      if storage as AnyObject === newStorage as AnyObject {
        continue
      }

      let existing = storage.metricDescriptor

      if existing.name.lowercased() == descriptor.name.lowercased(), existing != descriptor {
        // todo: log warning
        break
      }
    }

    return storage
  }
}
