//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

@testable import OpenTelemetryApi
import XCTest

/// A test case which registers a context manager before running its tests.
///
/// By creating a class that inherits from this class, you can define tests to be run for all context managers. Then define another class that inherits from it, and override the `contextManager` property. This subclass will run all of the tests defined in its superclass, but with its context manager set instead of the superclasses which will run with it's `contextManager`.
///
/// This allows tests to be reused without being manually copy and pasted.
open class ContextManagerTestCase: XCTestCase {
    /// Each subclass should override this property and return the context manager to run the tests with.
    open class var contextManager: ContextManager {
        DefaultContextManager()
    }

    open override class func setUp() {
        super.setUp()
        OpenTelemetry.registerContextManager(contextManager: self.contextManager)
    }
}

