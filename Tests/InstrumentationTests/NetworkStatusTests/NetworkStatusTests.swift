// Copyright © 2021 Elasticsearch BV
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//       http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.


#if os(iOS)
import Foundation
import Reachability
import CoreTelephony
import XCTest
@testable import NetworkStatus

class MockNetworkMonitor : INetworkMonitor {
    var connection : Connection
    init(connection: Connection) {
        self.connection = connection
    }
    func getConnection() -> Connection {
        return connection
    }

}


class MockCTTelephonyNetworkInfo : CTTelephonyNetworkInfo {
    let dsi : String?
    let ctc : CTCarrier?
    let crt : String?
    override var dataServiceIdentifier: String? {
        dsi
    }
    override var serviceSubscriberCellularProviders: [String : CTCarrier]? {
        if let dataServiceidentifier = dsi, let carrier = ctc {
            return [dataServiceidentifier : carrier]
        }
        return nil
    }
    
    override var serviceCurrentRadioAccessTechnology : [String: String]? {
        if let dataServiceIdentifier = dsi, let currentRadioTechnology = crt {
            return [dataServiceIdentifier : currentRadioTechnology]
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

class MockCTCarrier : CTCarrier {
    let cn : String?
    let iso : String?
    let mcc : String?
    let mnc : String?
    
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
        self.cn = carrierName
        self.iso = isoCountryCode
        self.mcc = mobileCountryCode
        self.mnc  = mobileNetworkCode
    }
}

final class InstrumentorTests: XCTestCase {
    func test() {
        let wifi_status = NetworkStatus(with: MockNetworkMonitor(connection: .wifi))
        
        
        var (type,subtype, info) = wifi_status.status()
        
        XCTAssertNil(info)
        XCTAssertEqual("wifi", type)
        
        let cell_status = NetworkStatus(with: MockNetworkMonitor(connection: .cellular),
                                        info: MockCTTelephonyNetworkInfo(dataServiceIndentifier: "blah",
                                                                         currentRadioAccessTechnology: "CTRadioAccessTechnologyEdge",
                                                                         carrier:MockCTCarrier(carrierName: "mobile-carrier", isoCountryCode: "1", mobileCountryCode: "120", mobileNetworkCode: "202")))
        
        (type,subtype, info) = cell_status.status()
        
        XCTAssertNotNil(info)
        XCTAssertEqual("mobile-carrier", info?.carrierName)
        XCTAssertEqual("1", info?.isoCountryCode)
        XCTAssertEqual("120", info?.mobileCountryCode)
        XCTAssertEqual("202", info?.mobileNetworkCode)
        XCTAssertEqual("cell", type)
        XCTAssertEqual("EDGE", subtype)
    
        let unavailable = NetworkStatus(with: MockNetworkMonitor(connection: .unavailable))
        
        (type,subtype, info) = unavailable.status()
        
        XCTAssertNil(info)
        
        XCTAssertEqual("unavailable", type)
        
    }
    func testEdgeCases() {
        let wifi_status = NetworkStatus(with: MockNetworkMonitor(connection: .wifi), info: MockCTTelephonyNetworkInfo(dataServiceIndentifier: nil, currentRadioAccessTechnology: nil, carrier: nil))
        
        var (type,subtype, info) = wifi_status.status()
        XCTAssertNil(info)
        XCTAssertEqual("wifi", type)
        
        
        let cell_status = NetworkStatus(with: MockNetworkMonitor(connection: .cellular), info: MockCTTelephonyNetworkInfo(dataServiceIndentifier: nil, currentRadioAccessTechnology: nil, carrier: nil))
        
        (type,subtype, info) = cell_status.status()
        
        XCTAssertNil(info)
        XCTAssertEqual("cell", type)
        
        
        let unavailable_status = NetworkStatus(with: MockNetworkMonitor(connection: .unavailable), info: MockCTTelephonyNetworkInfo(dataServiceIndentifier: nil, currentRadioAccessTechnology: nil, carrier: nil))
        
        (type,subtype, info) = unavailable_status.status()
        
        XCTAssertNil(info)
        XCTAssertEqual("unavailable", type)
        
    }
}

#endif //os(iOS)
