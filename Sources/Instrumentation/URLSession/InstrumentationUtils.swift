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

import Foundation

enum InstrumentationUtils {
    static func objc_getClassList() -> [AnyClass] {
        let expectedClassCount = ObjectiveC.objc_getClassList(nil, 0)
        let allClasses = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(expectedClassCount))
        let autoreleasingAllClasses = AutoreleasingUnsafeMutablePointer<AnyClass>(allClasses)
        let actualClassCount: Int32 = ObjectiveC.objc_getClassList(autoreleasingAllClasses, expectedClassCount)

        var classes = [AnyClass]()
        for i in 0 ..< actualClassCount {
            classes.append(allClasses[Int(i)])
        }
        allClasses.deallocate()
        return classes
    }

    static func instanceRespondsAndImplements(cls: AnyClass, selector: Selector) -> Bool {
        var implements = false
        if cls.instancesRespond(to: selector) {
            var methodCount: UInt32 = 0
            let methodList = class_copyMethodList(cls, &methodCount)
            defer {
                free(methodList)
            }
            if let methodList = methodList, methodCount > 0 {
                enumerateCArray(array: methodList, count: methodCount) { _, m in
                    let sel = method_getName(m)
                    if sel == selector {
                        implements = true
                        return
                    }
                }
            }
        }
        return implements
    }

    private static func enumerateCArray<T>(array: UnsafePointer<T>, count: UInt32, f: (UInt32, T) -> Void) {
        var ptr = array
        for i in 0 ..< count {
            f(i, ptr.pointee)
            ptr = ptr.successor()
        }
    }
}
