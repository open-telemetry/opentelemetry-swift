/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation


public protocol ObservableCounterMeter: ObservableMeter {
    associatedtype T
}


public struct NoopObservableCounterMeter<T> : ObservableCounterMeter {
    public typealias T = T
    public typealias U = NoopObservableResult<T>
    public private(set) var  callback: (U) -> ()
}
public typealias NoopObservableIntCounter = NoopObservableCounterMeter<UInt>
public typealias NoopObservableDoubleCounter = NoopObservableCounterMeter<Double>