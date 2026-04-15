/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(iOS) && !targetEnvironment(macCatalyst)
  import CoreTelephony
  import Foundation
  import Network

  /// Provides network connection type and carrier information for span attributes.
  ///
  /// ## Thread safety
  ///
  /// `CTTelephonyNetworkInfo` is not thread-safe: its Objective-C properties
  /// can be mutated internally by CoreTelephony on its own thread while being
  /// read from a caller's thread, causing `EXC_BAD_ACCESS` when the returned
  /// object is autoreleased after its backing memory has already been freed.
  ///
  /// To avoid this, we eagerly cache the telephony state and keep it up to date
  /// through `CTTelephonyNetworkInfoDelegate` callbacks (via a proxy object),
  /// which fire *after* the internal mutation has completed. Callers of
  /// `status()` read only the cached Swift values, protected by an `NSLock`,
  /// and never touch the underlying `CTTelephonyNetworkInfo` properties
  /// directly.
  public class NetworkStatus {
    public private(set) var networkInfo: CTTelephonyNetworkInfo
    public private(set) var networkMonitor: NetworkMonitorProtocol

    // MARK: - Cached telephony state

    /// Guards all reads and writes to the `cached*` properties below.
    private let lock = NSLock()

    private var cachedServiceId: String?
    private var cachedRadioTech: [String: String]?
    private var cachedProviders: [String: CTCarrier]?

    /// Delegate proxy that forwards `CTTelephonyNetworkInfoDelegate`
    /// callbacks to `refreshCachedState()`. Stored to prevent deallocation.
    private var delegateProxy: AnyObject?

    public convenience init() throws {
      try self.init(with: NetworkMonitor())
    }

    public init(with monitor: NetworkMonitorProtocol, info: CTTelephonyNetworkInfo = CTTelephonyNetworkInfo()) {
      networkMonitor = monitor
      networkInfo = info

      refreshCachedState()

      // Install a delegate so the cache stays current when the radio access
      // technology or active data service changes. The delegate callbacks
      // fire on CoreTelephony's internal serial queue *after* the property
      // mutation has settled, so reading the properties there is safe.
      if #available(iOS 13.0, *) {
        let proxy = NetworkInfoDelegateProxy { [weak self] in
          self?.refreshCachedState()
        }
        networkInfo.delegate = proxy
        delegateProxy = proxy
      }
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

    // MARK: - Private

    /// Snapshots the current `CTTelephonyNetworkInfo` state into Swift values.
    ///
    /// Safe to call from `init` (single-threaded) and from delegate callbacks
    /// (which fire on CoreTelephony's serial queue after the internal mutation
    /// has completed).
    fileprivate func refreshCachedState() {
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

  // MARK: - NetworkInfoDelegateProxy

  /// Lightweight `NSObject` subclass that bridges `CTTelephonyNetworkInfoDelegate`
  /// callbacks to a closure, keeping `NetworkStatus` itself a plain Swift class
  /// and preserving its existing public initializer signatures.
  @available(iOS 13.0, *)
  private class NetworkInfoDelegateProxy: NSObject, CTTelephonyNetworkInfoDelegate {
    private let onUpdate: () -> Void

    init(onUpdate: @escaping () -> Void) {
      self.onUpdate = onUpdate
    }

    func dataServiceIdentifierDidChange(_ identifier: String) {
      onUpdate()
    }

    func serviceCurrentRadioAccessTechnologyDidChange(
      _ serviceCurrentRadioAccessTechnology: [String: String]
    ) {
      onUpdate()
    }
  }

#endif // os(iOS) && !targetEnvironment(macCatalyst)
