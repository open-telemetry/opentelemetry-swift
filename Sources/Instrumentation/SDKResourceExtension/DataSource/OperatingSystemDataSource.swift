/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
#if os(watchOS)
    import WatchKit
#elseif os(macOS)
#else
    import UIKit
#endif

import Foundation

public class OperatingSystemDataSource: IOperatingSystemDataSource {
    public var description: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    public var type: String {
        #if os(watchOS)
            return "watchOS"
        #elseif os(macOS)
            return "macOS"
        #else
            return UIDevice.current.systemName
        #endif
    }
}
