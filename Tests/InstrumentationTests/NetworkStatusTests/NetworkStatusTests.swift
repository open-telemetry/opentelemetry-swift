/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(iOS) && !targetEnvironment(macCatalyst)
  import CoreTelephony
  import Foundation
  @testable import NetworkStatus

  import XCTest

  class MockNetworkMonitor: NetworkMonitorProtocol {
    var connection: Connection
    init(connection: Connection) {
      self.connection = connection
    }

    func getConnection() -> Connection {
      return connection
    }
  }

  class MockCTTelephonyNetworkInfo: CTTelephonyNetworkInfo {
    let dsi: String?
    let ctc: CTCarrier?
    let crt: String?
    override var dataServiceIdentifier: String? {
      dsi
    }

    override var serviceSubscriberCellularProviders: [String: CTCarrier]? {
      if let dataServiceidentifier = dsi, let carrier = ctc {
        return [dataServiceidentifier: carrier]
      }
      return nil
    }

    override var serviceCurrentRadioAccessTechnology: [String: String]? {
      if let dataServiceIdentifier = dsi, let currentRadioTechnology = crt {
        return [dataServiceIdentifier: currentRadioTechnology]
      }
      return nil
    }

    override var currentRadioAccessTechnology: String? {
      crt
    }

    public init(dataServiceIndentifier: String?, currentRadioAccessTechnology: String?, carrier: CTCarrier?) {
      dsi = dataServiceIndentifier
      ctc = carrier
      crt = currentRadioAccessTechnology
    }
  }

  class MockCTCarrier: CTCarrier {
    let cn: String?
    let iso: String?
    let mcc: String?
    let mnc: String?

    override var carrierName: String? {
      cn
    }

    override var isoCountryCode: String? {
      iso
    }

    override var mobileCountryCode: String? {
      mcc
    }

    override var mobileNetworkCode: String? {
      mnc
    }

    public init(carrierName: String?, isoCountryCode: String?, mobileCountryCode: String?, mobileNetworkCode: String?) {
      cn = carrierName
      iso = isoCountryCode
      mcc = mobileCountryCode
      mnc = mobileNetworkCode
    }
  }

  class MutableCTTelephonyNetworkInfo: CTTelephonyNetworkInfo {
    private let lock = NSLock()
    private var serviceId: String?
    private var radioTech: [String: String]?
    private var activeReads = 0
    private(set) var maxConcurrentReads = 0
    private(set) var totalReads = 0
    private let carrier = MockCTCarrier(carrierName: "TestCarrier", isoCountryCode: "US", mobileCountryCode: "310", mobileNetworkCode: "410")

    init(serviceId: String?, radioTech: [String: String]?) {
      self.serviceId = serviceId
      self.radioTech = radioTech
      super.init()
    }

    func set(serviceId: String?, radioTech: [String: String]?) {
      lock.lock()
      defer { lock.unlock() }
      self.serviceId = serviceId
      self.radioTech = radioTech
    }

    override var dataServiceIdentifier: String? {
      read { serviceId }
    }

    override var serviceCurrentRadioAccessTechnology: [String: String]? {
      read { radioTech }
    }

    override var serviceSubscriberCellularProviders: [String: CTCarrier]? {
      read { serviceId.map { [$0: carrier] } }
    }

    private func read<T>(_ value: () -> T) -> T {
      lock.lock()
      activeReads += 1
      totalReads += 1
      maxConcurrentReads = max(maxConcurrentReads, activeReads)
      lock.unlock()
      usleep(200)
      lock.lock()
      defer {
        activeReads -= 1
        lock.unlock()
      }
      return value()
    }
  }

  final class InstrumentorTests: XCTestCase {
    func test() {
      let wifi_status = NetworkStatus(with: MockNetworkMonitor(connection: .wifi))

      var (type, subtype, info) = wifi_status.status()

      XCTAssertNil(info)
      XCTAssertEqual("wifi", type)

      let cell_status = NetworkStatus(with: MockNetworkMonitor(connection: .cellular),
                                      info: MockCTTelephonyNetworkInfo(dataServiceIndentifier: "blah",
                                                                       currentRadioAccessTechnology: "CTRadioAccessTechnologyEdge",
                                                                       carrier: MockCTCarrier(carrierName: "mobile-carrier", isoCountryCode: "1", mobileCountryCode: "120", mobileNetworkCode: "202")))

      (type, subtype, info) = cell_status.status()

      XCTAssertNotNil(info)
      XCTAssertEqual("mobile-carrier", info?.carrierName)
      XCTAssertEqual("1", info?.isoCountryCode)
      XCTAssertEqual("120", info?.mobileCountryCode)
      XCTAssertEqual("202", info?.mobileNetworkCode)
      XCTAssertEqual("cell", type)
      XCTAssertEqual("EDGE", subtype)

      let unavailable = NetworkStatus(with: MockNetworkMonitor(connection: .unavailable))

      (type, subtype, info) = unavailable.status()

      XCTAssertNil(info)

      XCTAssertEqual("unavailable", type)
    }

    func testEdgeCases() {
      let wifi_status = NetworkStatus(with: MockNetworkMonitor(connection: .wifi), info: MockCTTelephonyNetworkInfo(dataServiceIndentifier: nil, currentRadioAccessTechnology: nil, carrier: nil))

      var (type, subtype, info) = wifi_status.status()
      XCTAssertNil(info)
      XCTAssertNil(subtype)
      XCTAssertEqual("wifi", type)

      let cell_status = NetworkStatus(with: MockNetworkMonitor(connection: .cellular), info: MockCTTelephonyNetworkInfo(dataServiceIndentifier: nil, currentRadioAccessTechnology: nil, carrier: nil))

      (type, subtype, info) = cell_status.status()

      XCTAssertNil(info)
      XCTAssertEqual("cell", type)

      let unavailable_status = NetworkStatus(with: MockNetworkMonitor(connection: .unavailable), info: MockCTTelephonyNetworkInfo(dataServiceIndentifier: nil, currentRadioAccessTechnology: nil, carrier: nil))

      (type, subtype, info) = unavailable_status.status()

      XCTAssertNil(info)
      XCTAssertEqual("unavailable", type)
    }

    func testConcurrentStatusAccess() {
      let netStatus = NetworkStatus(
        with: MockNetworkMonitor(connection: .cellular),
        info: MockCTTelephonyNetworkInfo(
          dataServiceIndentifier: "service1",
          currentRadioAccessTechnology: "CTRadioAccessTechnologyLTE",
          carrier: MockCTCarrier(
            carrierName: "TestCarrier",
            isoCountryCode: "US",
            mobileCountryCode: "310",
            mobileNetworkCode: "410"
          )
        )
      )

      DispatchQueue.concurrentPerform(iterations: 10_000) { _ in
        let (type, subtype, carrier) = netStatus.status()
        XCTAssertEqual("cell", type)
        XCTAssertEqual("LTE", subtype)
        XCTAssertEqual("TestCarrier", carrier?.carrierName)
      }
    }

    func testCellularSubtypeFollowsRadioTechnologyChangeNotification() {
      let info = MutableCTTelephonyNetworkInfo(serviceId: "service1",
                                               radioTech: ["service1": "CTRadioAccessTechnologyLTE"])
      let netStatus = NetworkStatus(with: MockNetworkMonitor(connection: .cellular), info: info)
      XCTAssertEqual("LTE", netStatus.status().1)

      info.set(serviceId: "service1", radioTech: ["service1": "CTRadioAccessTechnologyNR"])
      NotificationCenter.default.post(name: .CTServiceRadioAccessTechnologyDidChange, object: "service1")

      XCTAssertEqual("NR", netStatus.status().1)
    }

    func testConcurrentRefreshesNeverReadTelephonyInfoConcurrently() throws {
      let info = MutableCTTelephonyNetworkInfo(serviceId: "service1",
                                               radioTech: ["service1": "CTRadioAccessTechnologyLTE"])
      let netStatus = NetworkStatus(with: MockNetworkMonitor(connection: .cellular), info: info)
      let delegate = try XCTUnwrap(info.delegate)
      let readsBefore = info.totalReads
      let iterations = 64
      let refreshes = (0 ..< iterations).filter { $0 % 3 != 2 }.count

      DispatchQueue.concurrentPerform(iterations: iterations) { index in
        switch index % 3 {
        case 0:
          delegate.dataServiceIdentifierDidChange?("service1")
        case 1:
          NotificationCenter.default.post(name: .CTServiceRadioAccessTechnologyDidChange, object: "service1")
        default:
          _ = netStatus.status()
        }
      }

      XCTAssertGreaterThanOrEqual(info.totalReads - readsBefore, refreshes * 3)
      XCTAssertEqual(1, info.maxConcurrentReads)
    }
  }

#endif // os(iOS) && !targetEnvironment(macCatalyst)
