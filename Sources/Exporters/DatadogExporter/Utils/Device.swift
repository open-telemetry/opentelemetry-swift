/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if os(macOS)
import Foundation
import SystemConfiguration
#elseif os(iOS) || targetEnvironment(macCatalyst) || os(tvOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// Describes current mobile device.
internal class Device {
    // MARK: - Info

    var model: String
    var osName: String
    var osVersion: String

    init(
        model: String,
        osName: String,
        osVersion: String)
    {
        self.model = model
        self.osName = osName
        self.osVersion = osVersion
    }

    #if os(iOS) || targetEnvironment(macCatalyst)
    convenience init(uiDevice: UIDevice, processInfo: ProcessInfo) {
        self.init(
            model: uiDevice.model,
            osName: uiDevice.systemName,
            osVersion: uiDevice.systemVersion)
    }

    #elseif os(macOS)
    convenience init(processInfo: ProcessInfo) {
        self.init(
            model: "Mac",
            osName: processInfo.hostName,
            osVersion: processInfo.operatingSystemVersionString)
    }
    #endif

    /// Returns current mobile device  if `UIDevice` is available on this platform.
    /// On other platforms returns `nil`.
    static var current: Device {
        #if os(macOS)
        return Device(processInfo: ProcessInfo.processInfo)
        #elseif os(iOS) && !targetEnvironment(simulator)
        // Real device
        return Device(uiDevice: UIDevice.current, processInfo: ProcessInfo.processInfo)
        #elseif os(iOS) || os(tvOS)
        // iOS Simulator or tvOS - battery monitoring doesn't work on Simulator, so return "always OK" value
        return Device(
            model: UIDevice.current.model,
            osName: UIDevice.current.systemName,
            osVersion: UIDevice.current.systemVersion)
        #elseif os(watchOS)
        let device = WKInterfaceDevice.current()
        return Device(
            model: device.model,
            osName: device.systemName,
            osVersion: device.systemVersion)
        #endif
    }
}
