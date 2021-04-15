// Copyright 2021, OpenTelemetry Authors
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

import Foundation
#if os(watchOS)
    import WatchKit
#elseif os(macOS)
    import AppKit
#else
    import UIKit
#endif
public class DeviceDataSource: IDeviceDataSource {
    public var model: String? {
        #if os(watchOS)
            return WKInterfaceDevice.current().localizedModel
        #else
            let hwName = UnsafeMutablePointer<Int32>.allocate(capacity: 2)
            hwName[0] = CTL_HW
            #if os(macOS)
                hwName[1] = HW_MODEL
            #else
                hwName[1] = HW_MACHINE
            #endif
            let machine = UnsafeMutablePointer<CChar>.allocate(capacity: 255)
            let len: UnsafeMutablePointer<Int>! = UnsafeMutablePointer<Int>.allocate(capacity: 1)

            let error = sysctl(hwName, 2, machine, len, nil, 0)
            if error != 0 {
                // TODO: better error log
                print("error #\(errno): \(String(describing: String(utf8String: strerror(errno))))")

                return nil
            }
            let machineName = String(cString: machine)
            return machineName
        #endif
    }

    public var identifier: String? {
        #if os(watchOS)
            if #available(watchOS 6.3, *) {
                return WKInterfaceDevice.current().identifierForVendor?.uuidString
            } else {
                return nil
            }
        #elseif os(macOS)
            return nil
        #else
            return UIDevice.current.identifierForVendor?.uuidString

        #endif
    }
}
