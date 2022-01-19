/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi
public class ObservableCounterSdk<T> : ObservableCounterMeter {
    public typealias U = ObservableResultSdk<T>
    public private(set) var callback: (ObservableResultSdk<T>) -> () = { _ in
    }

    init(_ callback: @escaping (ObservableResultSdk<T>) -> ()) {
        self.callback = callback
    }
}

public typealias DoubleObservableCounterSdk = ObservableResultSdk<Double>
public typealias IntObservableCounterSdk = ObservableResultSdk<Int>
