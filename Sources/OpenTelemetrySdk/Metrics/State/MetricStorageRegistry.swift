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

      for existingStorage in registry.values {
        if existingStorage as AnyObject === newStorage as AnyObject {
          continue
        }

        let existing = existingStorage.metricDescriptor

        if existing.name.lowercased() == descriptor.name.lowercased(), existing != descriptor {
          OpenTelemetry.instance.feedbackHandler?("Found duplicate metric definition: \(descriptor.name). A metric with the same name but different identifying fields is already registered. To resolve, consider using a View to rename one of the instruments.")
          break
        }
      }

      return newStorage
    }

    return storage
  }
}
