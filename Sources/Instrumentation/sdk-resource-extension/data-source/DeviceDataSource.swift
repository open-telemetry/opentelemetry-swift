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

#if canImport(UIKit)
    import Foundation
    import UIKit

    public class DeviceDataSource: IDeviceDataSource {
        public var model: String? {
            let hwName = UnsafeMutablePointer<Int32>.allocate(capacity: 2)
            hwName[0] = CTL_HW
            hwName[1] = HW_MACHINE
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
        }

        public var identifier: String? {
            UIDevice.current.identifierForVendor?.uuidString
        }
    }
#endif // canImport(UIKit)
