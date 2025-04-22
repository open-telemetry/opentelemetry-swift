/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
#if canImport(UIKit) && !os(watchOS)
  import UIKit
#elseif os(watchOS)
  import WatchKit
#endif
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  import Darwin
#endif

protocol DeviceInformationSource {
  var osName: String { get }
  var osVersion: String { get }
  var deviceBrand: String { get } // e.g., "iPhone", "Apple Watch"
  var deviceModel: String { get } // e.g., "iPhone14,3", "Watch6,1", "MacBookPro18,1"
  var isPhysical: Bool { get }
}

// --- Concrete Device Information Sources ---

#if os(watchOS)
  struct WatchOSDeviceSource: DeviceInformationSource {
    private let device = WKInterfaceDevice.current()

    var osName: String { device.systemName }
    var osVersion: String { device.systemVersion }
    var deviceBrand: String { device.model } // e.g., "Apple Watch"
    var deviceModel: String { getDeviceIdentifier() }
    #if targetEnvironment(simulator)
      var isPhysical: Bool { false }
    #else
      var isPhysical: Bool { true }
    #endif
  }
#endif

#if os(iOS) || os(tvOS) || os(visionOS)
  struct IOSDeviceSource: DeviceInformationSource {
    private let device = UIDevice.current

    var osName: String { device.systemName }
    var osVersion: String { device.systemVersion }
    var deviceBrand: String { device.model } // e.g., "iPhone"
    var deviceModel: String { getDeviceIdentifier() }
    #if targetEnvironment(simulator)
      var isPhysical: Bool { false }
    #else
      var isPhysical: Bool { true }
    #endif
  }
#endif

#if os(macOS)
  struct MacOSDeviceSource: DeviceInformationSource {
    private let processInfo = ProcessInfo.processInfo

    var osName: String { "macOS" }
    var osVersion: String { processInfo.operatingSystemVersionString }
    var deviceBrand: String { "apple" }
    var deviceModel: String { getMacModelIdentifier() } // Use hw.model like "MacBookPro18,1"
    var isPhysical: Bool { true } // Assume physical

    // Private helper specific to macOS
    private func getMacModelIdentifier() -> String {
      var size = 0
      sysctlbyname("hw.model", nil, &size, nil, 0)
      var buffer = [CChar](repeating: 0, count: size)
      sysctlbyname("hw.model", &buffer, &size, nil, 0)
      return String(cString: buffer)
    }
  }
#endif

// Fallback for other potential future platforms
struct FallbackDeviceSource: DeviceInformationSource {
  private let processInfo = ProcessInfo.processInfo

  var osName: String { processInfo.operatingSystemVersionString }
  var osVersion: String { "" }
  var deviceBrand: String { "unknown" }
  var deviceModel: String { "unknown" }
  var isPhysical: Bool { true }
}

// --- Shared Helper Function for Device Model Detection ---
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  private func getDeviceIdentifier() -> String {
    #if targetEnvironment(simulator)
      // For simulators, use the environment variable which has the correct model ID
      if let simulatorModelId = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
        return simulatorModelId
      }
    #endif

    // For physical devices, get it from uname
    var systemInfo = utsname()
    uname(&systemInfo)

    let machineMirror = Mirror(reflecting: systemInfo.machine)
    return machineMirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8, value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
  }
#endif
