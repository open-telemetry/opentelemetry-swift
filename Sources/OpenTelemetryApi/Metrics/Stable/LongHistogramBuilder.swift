/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol LongHistogramBuilder : AnyObject {
    func build() -> LongHistogram
}
