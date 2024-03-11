//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class EmptyExponentialHistogramBuckets: ExponentialHistogramBuckets {
    
    public var scale: Int
    public var offset: Int = 0
    public var bucketCounts: [Int64] = []
    public var totalCount: Int = 0
    
    init(scale: Int) {
        self.scale = scale
    }
}

