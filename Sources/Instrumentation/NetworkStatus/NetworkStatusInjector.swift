/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(iOS)
import Foundation
import OpenTelemetryApi
import CoreTelephony
import Network
public class NetworkStatusInjector {
    private var netstat : NetworkStatus
    
    public init(netstat: NetworkStatus) {
        self.netstat = netstat
    }
    
    public func inject(span: Span) {
        let (type, subtype, carrier) = netstat.status()
        span.setAttribute(key: "net.host.connection.type", value:AttributeValue.string(type))

        if let subtype : String  = subtype {
            span.setAttribute(key: "net.host.connection.subtype", value: AttributeValue.string(subtype))
        }

        if let carrierInfo : CTCarrier = carrier {

            if let carrierName = carrierInfo.carrierName {
                span.setAttribute(key: "net.host.carrier.name", value: AttributeValue.string(carrierName))
            }
            
            if let isoCountryCode = carrierInfo.isoCountryCode {
                span.setAttribute(key: "net.host.carrier.icc", value: AttributeValue.string(isoCountryCode))
            }
            
            if let mobileCountryCode = carrierInfo.mobileCountryCode {
                span.setAttribute(key: "net.host.carrier.mcc", value: AttributeValue.string(mobileCountryCode))
            }
            
            if let mobileNetworkCode = carrierInfo.mobileNetworkCode {
                span.setAttribute(key: "net.host.carrier.mnc", value: AttributeValue.string(mobileNetworkCode))
            }
        }
    }
}
#endif
