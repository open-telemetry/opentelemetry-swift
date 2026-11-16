/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(iOS) && !targetEnvironment(macCatalyst)

  import CoreTelephony
  import Foundation
  import Network
  import OpenTelemetryApi

  // CTCarrier is deprecated since iOS 16; CTCarrier.h says it returns these placeholders "at some point in the future".
  private let ctCarrierPlaceholderValues: Set<String> = ["--", "65535"]

  public class NetworkStatusInjector {
    private var netstat: NetworkStatus

    public init(netstat: NetworkStatus) {
      self.netstat = netstat
    }

    public func inject(span: Span) {
      let (type, subtype, carrier) = netstat.status()
      span.setAttribute(key: SemanticConventions.Network.connectionType.rawValue, value: AttributeValue.string(type))

      if let subtype: String = subtype {
        span.setAttribute(key: SemanticConventions.Network.connectionSubtype.rawValue, value: AttributeValue.string(subtype))
      }

      if let carrierInfo: CTCarrier = carrier {
        setCarrierAttribute(on: span, key: SemanticConventions.Network.carrierName.rawValue, value: carrierInfo.carrierName)
        setCarrierAttribute(on: span, key: SemanticConventions.Network.carrierIcc.rawValue, value: carrierInfo.isoCountryCode)
        setCarrierAttribute(on: span, key: SemanticConventions.Network.carrierMcc.rawValue, value: carrierInfo.mobileCountryCode)
        setCarrierAttribute(on: span, key: SemanticConventions.Network.carrierMnc.rawValue, value: carrierInfo.mobileNetworkCode)
      }
    }

    private func setCarrierAttribute(on span: Span, key: String, value: String?) {
      guard let value, !ctCarrierPlaceholderValues.contains(value) else {
        return
      }
      span.setAttribute(key: key, value: AttributeValue.string(value))
    }
  }

#endif // os(iOS) && !targetEnvironment(macCatalyst)
