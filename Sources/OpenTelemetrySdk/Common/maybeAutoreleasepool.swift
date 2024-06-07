/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(ObjectiveC)
import ObjectiveC
#endif

/// Invokes the closure inside an autorelease pool if Objective-C is available. If not, the closure is called directly instead.
func maybeAutoreleasepool<Result>(invoking body: () throws -> Result) rethrows -> Result {
#if canImport(ObjectiveC)
    try autoreleasepool(invoking: body)
#else
    try body()
#endif
}
