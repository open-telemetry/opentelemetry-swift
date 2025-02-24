/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// No-op implementations of BaggageManager.
public class DefaultBaggageManagerProvider: BaggageManagerProvider {
  public static var instance = DefaultBaggageManagerProvider()

  public func create() -> BaggageManager {
    return DefaultBaggageManager.instance
  }
}
