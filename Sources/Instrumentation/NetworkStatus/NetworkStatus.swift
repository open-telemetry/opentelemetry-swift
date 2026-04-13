/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreTelephony
import Network

public class NetworkStatus {
    private let networkMonitor: NetworkMonitorProtocol
    
    // 缓存结构
    private struct CachedTelephonyInfo {
        var type: String = "cell"
        var name: String? = "unknown"
        var carrier: CTCarrier?
    }
    
    private var cachedTelephonyInfo = CachedTelephonyInfo()
    private let cacheLock = NSLock()

    public convenience init() throws {
        try self.init(with: NetworkMonitor())
    }

    public init(with monitor: NetworkMonitorProtocol) {
        self.networkMonitor = monitor
        startMonitoring()
    }
    
    let radioTechDidChangeNotification: NSNotification.Name = {
        if #available(iOS 12.0, *) {
            return .CTServiceRadioAccessTechnologyDidChange
        } else {
            // For iOS 11 and earlier (if needed)
            return .CTRadioAccessTechnologyDidChange
        }
    }()

    private func startMonitoring() {
        // 初始加载（必须在主线程）
        if Thread.isMainThread {
            refreshTelephonyCache()
        } else {
            DispatchQueue.main.sync {
                self.refreshTelephonyCache()
            }
        }
        
        // 监听网络变化（仅 iOS 12+ 支持该通知）
        NotificationCenter.default.addObserver(
            forName: radioTechDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.refreshTelephonyCache()
        }
    }

    // 🔒 仅在主线程调用
    private func refreshTelephonyCache() {
        assert(Thread.isMainThread, "refreshTelephonyCache must be called on main thread")
        
        let info = CTTelephonyNetworkInfo()
        
        if #available(iOS 13.0, *) {
            // iOS 13+
            if let serviceId = info.dataServiceIdentifier {
                let radioTech = info.serviceCurrentRadioAccessTechnology?[serviceId]
                let carrier = info.serviceSubscriberCellularProviders?[serviceId]
                let name = radioTech.flatMap(simpleConnectionName(connectionType:)) ?? "unknown"
                updateCache(type: "cell", name: name, carrier: carrier)
            }
        } else {
            // iOS 12 及以下，或 iOS 13+ 但 dataServiceIdentifier 为空（罕见）
            if let radioType = info.currentRadioAccessTechnology {
                let name = simpleConnectionName(connectionType: radioType)
                updateCache(type: "cell", name: name, carrier: info.subscriberCellularProvider)
            } else {
                updateCache(type: "cell", name: "unknown", carrier: nil)
            }
        }
    }

    private func updateCache(type: String, name: String?, carrier: CTCarrier?) {
        cacheLock.lock()
        cachedTelephonyInfo.type = type
        cachedTelephonyInfo.name = name
        cachedTelephonyInfo.carrier = carrier
        cacheLock.unlock()
    }

    private func getCachedTelephonyInfo() -> (type: String, name: String?, carrier: CTCarrier?) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return (cachedTelephonyInfo.type, cachedTelephonyInfo.name, cachedTelephonyInfo.carrier)
    }

    // ✅ 同步方法，任意线程安全调用
    public func status() -> (String, String?, CTCarrier?) {
        let connection = networkMonitor.getConnection()
        
        switch connection {
        case .wifi:
            return ("wifi", nil, nil)
            
        case .unavailable:
            return ("unavailable", nil, nil)
            
        case .cellular:
            // 始终返回缓存值（主线程定期更新）
            let cached = getCachedTelephonyInfo()
            return (cached.type, cached.name, cached.carrier)
        }
    }

    private func simpleConnectionName(connectionType: String) -> String {
        switch connectionType {
        case "CTRadioAccessTechnologyEdge": return "EDGE"
        case "CTRadioAccessTechnologyCDMA1x": return "CDMA"
        case "CTRadioAccessTechnologyGPRS": return "GPRS"
        case "CTRadioAccessTechnologyWCDMA": return "WCDMA"
        case "CTRadioAccessTechnologyHSDPA": return "HSDPA"
        case "CTRadioAccessTechnologyHSUPA": return "HSUPA"
        case "CTRadioAccessTechnologyCDMAEVDORev0": return "EVDO_0"
        case "CTRadioAccessTechnologyCDMAEVDORevA": return "EVDO_A"
        case "CTRadioAccessTechnologyCDMAEVDORevB": return "EVDO_B"
        case "CTRadioAccessTechnologyeHRPD": return "HRPD"
        case "CTRadioAccessTechnologyLTE": return "LTE"
        case "CTRadioAccessTechnologyNRNSA": return "NRNSA"
        case "CTRadioAccessTechnologyNR": return "NR"
        default: return "unknown"
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

#endif // os(iOS) && !targetEnvironment(macCatalyst)
