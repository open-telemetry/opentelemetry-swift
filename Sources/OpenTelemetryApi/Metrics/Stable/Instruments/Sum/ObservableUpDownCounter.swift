/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

protocol ObservableUpDownCounter : ObservableMeter {
    associatedtype T
}

public struct NoopObservableUpDownCounter<T> : ObservableUpDownCounter {
    public typealias T = T
    public typealias U = NoopObservableResult<T>
    public private(set) var callback: (U) -> ()
}
public typealias NoopObservableIntUpDownCounter = NoopObservableUpDownCounter<Int>
public typealias NoopObservableDoubleUpDownCounter = NoopObservableUpDownCounter<Double>