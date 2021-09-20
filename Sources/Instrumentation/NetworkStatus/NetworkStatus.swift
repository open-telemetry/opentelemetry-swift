/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreTelephony
import Foundation
import Network

public class NetworkStatus {
    public private(set) var networkInfo: CTTelephonyNetworkInfo
    public private(set) var networkMonitor: NetworkMonitorProtocol
    public convenience init() throws {
        self.init(with: try NetworkMonitor())
    }

    public init(with monitor: NetworkMonitorProtocol, info: CTTelephonyNetworkInfo = CTTelephonyNetworkInfo()) {
        networkMonitor = monitor
        networkInfo = info
    }

    public func status() -> (String, String?, CTCarrier?) {
        switch networkMonitor.getConnection() {
        case .wifi:
            return ("wifi", nil, nil)
        case .cellular:
            if #available(iOS 13.0, *) {
                if let serviceId = networkInfo.dataServiceIdentifier, let value = networkInfo.serviceCurrentRadioAccessTechnology?[serviceId] {
                    return ("cell", simpleConnectionName(connectionType: value), networkInfo.serviceSubscriberCellularProviders?[networkInfo.dataServiceIdentifier!])
                }
            } else {
                if let radioType = networkInfo.currentRadioAccessTechnology {
                    return ("cell", simpleConnectionName(connectionType: radioType), networkInfo.subscriberCellularProvider)
                }
            }
            return ("cell", "unknown", nil)
        case .unavailable:
            return ("unavailable", nil, nil)
        }
    }

    func simpleConnectionName(connectionType: String) -> String {
        switch connectionType {
        case "CTRadioAccessTechnologyEdge":
            return "EDGE"
        case "CTRadioAccessTechnologyCDMA1x":
            return "CDMA"
        case "CTRadioAccessTechnologyGPRS":
            return "GPRS"
        case "CTRadioAccessTechnologyWCDMA":
            return "WCDMA"
        case "CTRadioAccessTechnologyHSDPA":
            return "HSDPA"
        case "CTRadioAccessTechnologyHSUPA":
            return "HSUPA"
        case "CTRadioAccessTechnologyCDMAEVDORev0":
            return "EVDO_0"
        case "CTRadioAccessTechnologyCDMAEVDORevA":
            return "EVDO_A"
        case "CTRadioAccessTechnologyCDMAEVDORevB":
            return "EVDO_B"
        case "CTRadioAccessTechnologyeHRPD":
            return "HRPD"
        case "CTRadioAccessTechnologyLTE":
            return "LTE"
        case "CTRadioAccessTechnologyNRNSA":
            return "NRNSA"
        case "CTRadioAccessTechnologyNR":
            return "NR"
        default:
            return "unknown"
        }
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
