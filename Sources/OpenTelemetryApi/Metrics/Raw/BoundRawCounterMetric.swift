/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

open class BoundRawCounterMetric<T> {
    public init() {}
    
    open func record(sum: T, startDate: Date, endDate: Date) {}
}
