/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public class ApplicationDataSource: IApplicationDataSource {
    public init() {}
    
    public var name: String? {
        Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String
    }

    public var identifier: String? {
        Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String] as? String
    }

    public var version: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    public var build: String? {
        Bundle.main.infoDictionary?[kCFBundleVersionKey as String] as? String
    }
}
