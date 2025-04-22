/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

protocol PersistentDeviceIdentifierProviding {
  func getIdentifier() -> String
}

class FaroPersistentDeviceIdentifierProvider: PersistentDeviceIdentifierProviding {
  private static let faroDeviceIdUserDefaultsKey = "faro.device_id"
  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  func getIdentifier() -> String {
    if let existingId = userDefaults.string(forKey: Self.faroDeviceIdUserDefaultsKey) {
      return existingId
    } else {
      let newId = UUID().uuidString
      userDefaults.set(newId, forKey: Self.faroDeviceIdUserDefaultsKey)
      return newId
    }
  }
}
