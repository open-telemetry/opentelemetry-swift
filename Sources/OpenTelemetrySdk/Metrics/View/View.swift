/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

@available(*, deprecated, renamed: "View")
public typealias StableView = View

public class View {
  public private(set) var name: String?
  public private(set) var description: String?
  public private(set) var aggregation: Aggregation
  public private(set) var attributeProcessor: AttributeProcessor
  init(name: String?, description: String?, aggregation: Aggregation, attributeProcessor: AttributeProcessor) {
    self.name = name
    self.description = description
    self.aggregation = aggregation
    self.attributeProcessor = attributeProcessor
  }

  public static func builder() -> ViewBuilder {
    return ViewBuilder()
  }
}
