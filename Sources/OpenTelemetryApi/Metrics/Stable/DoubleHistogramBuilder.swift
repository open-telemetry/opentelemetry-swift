/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public protocol DoubleHistogramBuilder: AnyObject {
  associatedtype AnyLongHistogramBuilder : LongHistogramBuilder
  associatedtype AnyDoubleHistogram : DoubleHistogram
  func ofLongs() -> AnyLongHistogramBuilder

  func build() -> AnyDoubleHistogram
}
