/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */
 
import Foundation

/// Protocol for providing current date, making it easier to test time-dependent logic
public protocol DateProviding {
    /// Returns the current date
    func currentDate() -> Date
}

/// Default implementation of DateProviding that returns the actual current date
public class DateProvider: DateProviding {
    public init() {}
    
    public func currentDate() -> Date {
        return Date()
    }
} 