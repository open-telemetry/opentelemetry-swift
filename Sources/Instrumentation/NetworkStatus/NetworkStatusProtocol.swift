/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(iOS)
import Foundation
import CoreTelephony

public protocol NetworkStatusProtocol {
    var networkMonitor : NetworkMonitorProtocol { get }
    func getStatus() -> (String, CTCarrier?)
}
#endif
