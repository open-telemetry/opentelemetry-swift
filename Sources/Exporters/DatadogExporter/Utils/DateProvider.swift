/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Interface for date provider used for files orchestration.
protocol DateProvider {
  func currentDate() -> Date
}

struct SystemDateProvider: DateProvider {
  @inlinable
  func currentDate() -> Date { return Date() }
}
