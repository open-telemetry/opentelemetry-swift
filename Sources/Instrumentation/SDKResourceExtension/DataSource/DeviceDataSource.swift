/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
#if os(watchOS)
    import WatchKit
#elseif os(macOS)
    import AppKit
#else
    import UIKit
#endif
public class DeviceDataSource: IDeviceDataSource {
    public init() {}

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

            // Returned 'error #12: Optional("Cannot allocate memory")' because len was not initialized properly.

            let desiredLen = UnsafeMutablePointer<Int>.allocate(capacity: 1)
            
            sysctl(hwName, 2, nil, desiredLen, nil, 0)

            let machine = UnsafeMutablePointer<CChar>.allocate(capacity: desiredLen[0])
            let len: UnsafeMutablePointer<Int>! = UnsafeMutablePointer<Int>.allocate(capacity: 1)
            len[0] = desiredLen[0]

            let modelRequestError = sysctl(hwName, 2, machine, len, nil, 0)
            if modelRequestError != 0 {
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
