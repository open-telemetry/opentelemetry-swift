//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public struct ValueAtQuantile: Codable {
  public let quantile: Double
  public let value: Double
}
