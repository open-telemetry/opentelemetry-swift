//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class ViewBuilder {
  private var name: String?

  private var description: String?

  private var aggregation: Aggregation = Aggregations.defaultAggregation()

  private var processor: AttributeProcessor = NoopAttributeProcessor.noop

  public func withName(name: String) -> Self {
    self.name = name
    return self
  }

  public func withDescription(description: String) -> Self {
    self.description = description
    return self
  }

  public func withAggregation(aggregation: Aggregation) -> Self {
    self.aggregation = aggregation
    return self
  }

  public func withAttributeProcessor(processor: AttributeProcessor) -> Self {
    self.processor = processor
    return self
  }

  public func addAttributeFilter(keyFilter: @escaping (String) -> Bool) -> Self {
    addAttributeProcessor(processor: SimpleAttributeProcessor.filterByKeyName(nameFilter: keyFilter))
  }

  public func addAttributeProcessor(processor: AttributeProcessor) -> Self {
    self.processor = self.processor.then(other: processor)
    return self
  }

  public func build() -> View {
    return View(
      name: name,
      description: description,
      aggregation: aggregation,
      attributeProcessor: processor
    )
  }
}
