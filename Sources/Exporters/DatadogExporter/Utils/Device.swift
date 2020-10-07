// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#if !os(macOS)
import UIKit
#else
import Foundation
import SystemConfiguration
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
        osVersion: String) {
        self.model = model
        self.osName = osName
        self.osVersion = osVersion
    }

    #if !os(macOS)
    convenience init(uiDevice: UIDevice, processInfo: ProcessInfo) {
        self.init(
            model: uiDevice.model,
            osName: uiDevice.systemName,
            osVersion: uiDevice.systemVersion)
    }
    #else
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
        #else
        // iOS Simulator or tvOS - battery monitoring doesn't work on Simulator, so return "always OK" value
        return Device(
            model: UIDevice.current.model,
            osName: UIDevice.current.systemName,
            osVersion: UIDevice.current.systemVersion)
        #endif
    }
}
