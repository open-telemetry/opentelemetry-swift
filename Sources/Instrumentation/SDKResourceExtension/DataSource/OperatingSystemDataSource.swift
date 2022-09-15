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
import OpenTelemetrySdk

public class OperatingSystemDataSource: IOperatingSystemDataSource {
    public init() {}
    public var description: String {
        name + " " + ProcessInfo.processInfo.operatingSystemVersionString
    }

    public var type: String {
        ResourceAttributes.OsTypeValues.darwin.description
    }
    
    public var name: String {
        #if os(watchOS)
            return "watchOS"
        #elseif os(macOS)
            return "macOS"
        #else
            return UIDevice.current.systemName
        #endif
    }
    
    public var version: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
}
