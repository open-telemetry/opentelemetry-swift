/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// No-op implementations of BaggageManager.
public class DefaultBaggageManager: BaggageManager {
  private init() {}

  ///  Returns a BaggageManager singleton that is the default implementation for
  ///  BaggageManager.
  public static var instance = DefaultBaggageManager()

  public func baggageBuilder() -> BaggageBuilder {
    return DefaultBaggageBuilder()
  }

  public func getCurrentBaggage() -> Baggage? {
    return OpenTelemetry.instance.contextProvider.activeBaggage
  }
}
