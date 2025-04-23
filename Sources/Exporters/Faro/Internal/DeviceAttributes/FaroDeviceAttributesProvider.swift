/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

/// Protocol for providing device-specific attributes.
protocol FaroDeviceAttributesProviding {
  func getDeviceAttributes() -> [String: String]
}

class FaroDeviceAttributesProvider: FaroDeviceAttributesProviding {
  private let source: DeviceInformationSource
  private let identifierProvider: PersistentDeviceIdentifierProviding

  init(source: DeviceInformationSource, identifierProvider: PersistentDeviceIdentifierProviding) {
    self.source = source
    self.identifierProvider = identifierProvider
  }

  func getDeviceAttributes() -> [String: String] {
    var faroAttributes: [String: String] = [:]

    // Set base/shared attributes
    faroAttributes["device_manufacturer"] = "apple"
    faroAttributes["device_id"] = identifierProvider.getIdentifier()

    // Use the injected source for platform details
    faroAttributes["device_os"] = source.osName
    faroAttributes["device_os_version"] = source.osVersion
    faroAttributes["device_os_detail"] = "\(source.osName) \(source.osVersion)"
    faroAttributes["device_brand"] = source.deviceBrand
    faroAttributes["device_model"] = source.deviceModel
    faroAttributes["device_is_physical"] = source.isPhysical ? "true" : "false"

    return faroAttributes
  }
}

/// Factory for creating FaroDeviceAttributesProviding instances.
class FaroDeviceAttributesProviderFactory {
  static func createProvider() -> FaroDeviceAttributesProviding {
    #if os(watchOS)
      let source = WatchOSDeviceSource()
    #elseif os(iOS) || os(tvOS) || os(visionOS)
      let source = IOSDeviceSource()
    #elseif os(macOS)
      let source = MacOSDeviceSource()
    #else
      let source = FallbackDeviceSource()
    #endif

    let identifierProvider = FaroPersistentDeviceIdentifierProvider()
    return FaroDeviceAttributesProvider(source: source, identifierProvider: identifierProvider)
  }
}
