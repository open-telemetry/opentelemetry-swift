/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(iOS) && !targetEnvironment(macCatalyst)
  import CoreTelephony
  import Foundation
  @testable import NetworkStatus
  import OpenTelemetryApi
  import OpenTelemetrySdk

  import XCTest

  final class NetworkStatusInjectorTests: XCTestCase {
    private let carrierAttributeKeys = [
      SemanticConventions.Network.carrierName.rawValue,
      SemanticConventions.Network.carrierIcc.rawValue,
      SemanticConventions.Network.carrierMcc.rawValue,
      SemanticConventions.Network.carrierMnc.rawValue,
    ]

    private func injectedAttributes(carrier: CTCarrier) -> [String: AttributeValue] {
      let netstat = NetworkStatus(
        with: MockNetworkMonitor(connection: .cellular),
        info: MockCTTelephonyNetworkInfo(
          dataServiceIndentifier: "service1",
          currentRadioAccessTechnology: "CTRadioAccessTechnologyLTE",
          carrier: carrier
        )
      )
      let tracer = TracerProviderSdk().get(instrumentationName: "NetworkStatusInjectorTests")
      let span = tracer.spanBuilder(spanName: "request").startSpan()
      NetworkStatusInjector(netstat: netstat).inject(span: span)
      span.end()
      guard let readable = span as? ReadableSpan else {
        XCTFail("expected an SDK span")
        return [:]
      }
      return readable.toSpanData().attributes
    }

    private func assertConnectionAttributes(_ attributes: [String: AttributeValue], file: StaticString = #filePath, line: UInt = #line) {
      XCTAssertEqual(attributes[SemanticConventions.Network.connectionType.rawValue], .string("cell"), file: file, line: line)
      XCTAssertEqual(attributes[SemanticConventions.Network.connectionSubtype.rawValue], .string("LTE"), file: file, line: line)
    }

    func testPlaceholderCarrierValuesAreNotInjected() {
      let attributes = injectedAttributes(
        carrier: MockCTCarrier(carrierName: "--", isoCountryCode: "--", mobileCountryCode: "65535", mobileNetworkCode: "65535")
      )

      assertConnectionAttributes(attributes)
      for key in carrierAttributeKeys {
        XCTAssertNil(attributes[key], "\(key) = \(String(describing: attributes[key]))")
      }
    }

    func testRealCarrierValuesAreInjected() {
      let attributes = injectedAttributes(
        carrier: MockCTCarrier(carrierName: "mobile-carrier", isoCountryCode: "1", mobileCountryCode: "120", mobileNetworkCode: "202")
      )

      assertConnectionAttributes(attributes)
      XCTAssertEqual(attributes[SemanticConventions.Network.carrierName.rawValue], .string("mobile-carrier"))
      XCTAssertEqual(attributes[SemanticConventions.Network.carrierIcc.rawValue], .string("1"))
      XCTAssertEqual(attributes[SemanticConventions.Network.carrierMcc.rawValue], .string("120"))
      XCTAssertEqual(attributes[SemanticConventions.Network.carrierMnc.rawValue], .string("202"))
    }
  }

#endif // os(iOS) && !targetEnvironment(macCatalyst)
