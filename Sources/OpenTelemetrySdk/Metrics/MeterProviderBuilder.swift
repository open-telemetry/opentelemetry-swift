/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

@available(*, deprecated, renamed: "MeterProviderBuilder")
public typealias StableMeterProviderBuilder = MeterProviderBuilder

public class MeterProviderBuilder {
  public private(set) var clock: Clock = MillisClock()
  public private(set) var resource: Resource = .init()
  public private(set) var metricReaders = [MetricReader]()
  public private(set) var registeredViews = [RegisteredView]()
  public private(set) var exemplarFilter: ExemplarFilter = AlwaysOnFilter()

  init() {}

  public func setClock(clock: Clock) -> Self {
    self.clock = clock
    return self
  }

  public func setResource(resource: Resource) -> Self {
    self.resource = resource
    return self
  }

  public func registerView(selector: InstrumentSelector, view: View) -> Self {
    registeredViews.append(RegisteredView(selector: selector, view: view, attributeProcessor: view.attributeProcessor))
    return self
  }

  public func registerMetricReader(reader: MetricReader) -> Self {
    metricReaders.append(reader)
    return self
  }

  public func setExemplarFilter(exemplarFilter: ExemplarFilter) -> Self {
    self.exemplarFilter = exemplarFilter
    return self
  }

  public func build() -> MeterProviderSdk {
    MeterProviderSdk(registeredViews: registeredViews, metricReaders: metricReaders, clock: clock, resource: resource, exemplarFilter: exemplarFilter)
  }
}
