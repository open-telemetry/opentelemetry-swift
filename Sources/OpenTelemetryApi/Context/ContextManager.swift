/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol ContextManager: AnyObject {
    func getCurrentContextValue(forKey: String) -> AnyObject?
    func setCurrentContextValue(forKey: String, value: AnyObject)
    func removeContextValue(forKey: String, value: AnyObject)
}
