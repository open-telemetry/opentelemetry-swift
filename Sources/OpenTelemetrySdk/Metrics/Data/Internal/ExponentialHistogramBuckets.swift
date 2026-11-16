//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public protocol ExponentialHistogramBuckets: Codable {
  var scale: Int { get }
  var offset: Int { get }
  var bucketCounts: [Int64] { get }
  var totalCount: Int { get }
}
