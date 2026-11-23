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

    private let lock = NSLock()
    private let refreshLock = NSLock()
    private var cachedServiceId: String?
    private var cachedRadioTech: [String: String]?
    private var cachedProviders: [String: CTCarrier]?
    private var delegateProxy: AnyObject?

    public convenience init() throws {
      try self.init(with: NetworkMonitor())
    }

    public init(with monitor: NetworkMonitorProtocol, info: CTTelephonyNetworkInfo = CTTelephonyNetworkInfo()) {
      networkMonitor = monitor
      networkInfo = info

      if #available(iOS 13.0, *) {
        let proxy = NetworkInfoDelegateProxy { [weak self] in
          self?.refreshCachedState()
        }
        networkInfo.delegate = proxy
        delegateProxy = proxy
      }

      refreshCachedState()
    }

    public func status() -> (String, String?, CTCarrier?) {
      switch networkMonitor.getConnection() {
      case .wifi:
        return ("wifi", nil, nil)
      case .cellular:
        if #available(iOS 13.0, *) {
          lock.lock()
          let serviceId = cachedServiceId
          let radioTech = cachedRadioTech
          let providers = cachedProviders
          lock.unlock()

          if let serviceId, let value = radioTech?[serviceId] {
            return ("cell", simpleConnectionName(connectionType: value), providers?[serviceId])
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

    /// Snapshots the current `CTTelephonyNetworkInfo` state into the cached properties.
    /// Serialised, because the delegate and the radio notification can fire together on different queues.
    fileprivate func refreshCachedState() {
      refreshLock.lock()
      defer { refreshLock.unlock() }
      let serviceId = networkInfo.dataServiceIdentifier
      let radioTech = networkInfo.serviceCurrentRadioAccessTechnology
      let providers = networkInfo.serviceSubscriberCellularProviders

      lock.lock()
      cachedServiceId = serviceId
      cachedRadioTech = radioTech
      cachedProviders = providers
      lock.unlock()
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

  /// Forwards `CTTelephonyNetworkInfoDelegate` callbacks and radio technology changes to a closure.
  /// The delegate reports only data-service switches; radio changes arrive as a notification.
  @available(iOS 13.0, *)
  private class NetworkInfoDelegateProxy: NSObject, CTTelephonyNetworkInfoDelegate {
    private let onUpdate: () -> Void

    init(onUpdate: @escaping () -> Void) {
      self.onUpdate = onUpdate
      super.init()
      NotificationCenter.default.addObserver(self,
                                             selector: #selector(radioAccessTechnologyDidChange(_:)),
                                             name: .CTServiceRadioAccessTechnologyDidChange,
                                             object: nil)
    }

    func dataServiceIdentifierDidChange(_ identifier: String) {
      onUpdate()
    }

    @objc private func radioAccessTechnologyDidChange(_ notification: Notification) {
      onUpdate()
    }
  }

#endif // os(iOS) && !targetEnvironment(macCatalyst)
