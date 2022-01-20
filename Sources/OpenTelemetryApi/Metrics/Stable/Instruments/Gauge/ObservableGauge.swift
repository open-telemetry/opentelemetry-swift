/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol ObservableGauge : ObservableMeter {
    associatedtype T
}

public struct NoopObservableGauge<T> : ObservableGauge {
    public typealias U = NoopObservableResult<T>
    public private(set) var callback: (U) -> ()
}

