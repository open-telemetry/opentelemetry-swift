/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import Reachability

public class NetworkMonitor : NetworkMonitorProtocol {
    public private(set) var reachability :Reachability
    
    public init() throws {
        reachability = try Reachability()
        try reachability.startNotifier()
    }

    deinit {
        reachability.stopNotifier()
    }
    
    public func getConnection() -> Connection {
        switch reachability.connection {
        case .wifi:
            return .wifi
        case .cellular:
            return .cellular
        case .unavailable:
            return .unavailable
        }
    }
    
    
}
