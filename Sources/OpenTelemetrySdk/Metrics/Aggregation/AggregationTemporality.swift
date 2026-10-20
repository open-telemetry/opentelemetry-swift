//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public protocol AggregationTemporalitySelectorProtocol: Sendable {
  func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality
}

public final class AggregationTemporalitySelector: AggregationTemporalitySelectorProtocol {
  public func getAggregationTemporality(for instrument: InstrumentType) -> AggregationTemporality {
    return aggregationTemporalitySelector(instrument)
  }

  public init(aggregationTemporalitySelector: @escaping @Sendable (InstrumentType) -> AggregationTemporality) {
    self.aggregationTemporalitySelector = aggregationTemporalitySelector
  }

  public let aggregationTemporalitySelector: @Sendable (InstrumentType) -> AggregationTemporality
}

public enum AggregationTemporality: Codable, Sendable {
  case delta
  case cumulative

  public static func alwaysCumulative() -> AggregationTemporalitySelector {
    return AggregationTemporalitySelector { _ in
      .cumulative
    }
  }

  public static func alwaysDelta() -> AggregationTemporalitySelector {
    return AggregationTemporalitySelector { _ in
      .delta
    }
  }

  public static func deltaPreferred() -> AggregationTemporalitySelector {
    return AggregationTemporalitySelector { type in
      switch type {
      case .upDownCounter, .observableUpDownCounter:
        return .cumulative
      case .counter, .observableCounter, .histogram, .observableGauge, .gauge:
        return .delta
      }
    }
  }
}
