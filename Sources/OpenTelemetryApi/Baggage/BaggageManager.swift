/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Object for creating new Baggages and Baggages based on the
/// current context.
/// This class returns Baggage builders that can be used to create the
/// implementation-dependent Baggages.
/// Implementations may have different constraints and are free to convert entry contexts to their
/// own subtypes. This means callers cannot assume the getCurrentContext()
/// is the same instance as the one withContext() placed into scope.
public protocol BaggageManager: AnyObject {
    /// Returns a new ContextBuilder.
    func baggageBuilder() -> BaggageBuilder
}
