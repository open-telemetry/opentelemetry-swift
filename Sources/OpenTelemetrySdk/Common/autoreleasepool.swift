/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(ObjectiveC)
  import ObjectiveC
#endif

#if !canImport(ObjectiveC)
  /// Mocks out ObjectiveC's `autoreleasepool` function by simply calling the closure directly on platforms without Objective-C support
  func autoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
    try body()
  }
#endif
