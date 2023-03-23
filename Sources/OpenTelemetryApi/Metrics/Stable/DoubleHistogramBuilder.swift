/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleHistogramBuilder {
    func ofLongs() -> LongHistogramBuilder

    func build() -> DoubleHistogram
}
