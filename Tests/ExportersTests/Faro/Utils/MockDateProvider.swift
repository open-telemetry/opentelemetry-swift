/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
 
import Foundation
@testable import FaroExporter

/// A mock implementation of DateProviding for testing purposes
final class MockDateProvider: DateProviding {
    private var internalCurrentDate: Date
    
    init(initialDate: Date = Date()) {
        self.internalCurrentDate = initialDate
    }
    
    func currentDate() -> Date {
        return internalCurrentDate
    }
    
    /// Advances the mock's current date by the specified time interval
    /// - Parameter timeInterval: The amount of time to advance by
    func advance(by timeInterval: TimeInterval) {
        internalCurrentDate = internalCurrentDate.addingTimeInterval(timeInterval)
    }
} 