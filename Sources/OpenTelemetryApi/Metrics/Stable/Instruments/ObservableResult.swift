/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol ObservableResult {
    associatedtype T
    func observe(_ value: T, attributes: [String: AttributeValue]?)
}

public struct NoopObservableResult<T> : ObservableResult {
    init() {}
    public func observe(_ value: T, attributes: [String: AttributeValue]?) {

    }
}
