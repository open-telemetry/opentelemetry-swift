/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

protocol PersistentDeviceIdentifierProviding {
  func getIdentifier() -> String
}

protocol UserDefaultsProviding {
  func string(forKey defaultName: String) -> String?
  func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: UserDefaultsProviding {}

class FaroPersistentDeviceIdentifierProvider: PersistentDeviceIdentifierProviding {
  private static let faroDeviceIdUserDefaultsKey = "faro.device_id"
  private let storage: UserDefaultsProviding

  init(storage: UserDefaultsProviding = UserDefaults.standard) {
    self.storage = storage
  }

  func getIdentifier() -> String {
    if let existingId = storage.string(forKey: Self.faroDeviceIdUserDefaultsKey) {
      return existingId
    } else {
      let newId = UUID().uuidString
      storage.set(newId, forKey: Self.faroDeviceIdUserDefaultsKey)
      return newId
    }
  }
}
