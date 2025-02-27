//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public typealias AggregationResolver = (InstrumentType) -> Aggregation

public protocol DefaultAggregationSelector {
  func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation
}

public class AggregationSelector: DefaultAggregationSelector {
  public static let instance = AggregationSelector()

  public let selector: AggregationResolver

  init(selector: @escaping AggregationResolver = AggregationSelector.defaultSelector()) {
    self.selector = selector
  }

  public func getDefaultAggregation(for instrument: InstrumentType) -> Aggregation {
    return selector(instrument)
  }

  public static func defaultSelector() -> AggregationResolver {
    return { _ in
      return Aggregations.defaultAggregation()
    }
  }

  public func with(instrumentType: InstrumentType, aggregation: Aggregation) -> AggregationResolver {
    return { instrumentType1 in
      if instrumentType == instrumentType1 {
        return aggregation
      }
      return self.selector(instrumentType1)
    }
  }
}
