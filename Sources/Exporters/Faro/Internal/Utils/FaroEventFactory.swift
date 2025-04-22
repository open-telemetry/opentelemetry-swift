/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

extension FaroEvent {
  /// Shared date provider instance
  private static let sharedDateProvider = DateProvider()

  /// Factory method to create a FaroEvent with current timestamp
  /// - Parameters:
  ///   - name: The name of the event
  ///   - attributes: Optional event attributes
  ///   - trace: Optional trace context
  /// - Returns: A new FaroEvent instance
  static func create(name: String,
                     attributes: [String: String] = [:],
                     trace: FaroTraceContext? = nil) -> FaroEvent {
    let currentDate = sharedDateProvider.currentDate()
    return FaroEvent(
      name: name,
      attributes: attributes,
      timestamp: sharedDateProvider.iso8601String(from: currentDate),
      dateTimestamp: currentDate,
      trace: trace
    )
  }
}
