//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

@available(*, deprecated, renamed: "NoopMeterProviderBuilder")
public typealias NoopStableMeterProviderBuilder = NoopMeterProviderBuilder

public class NoopMeterProviderBuilder {
  public private(set) var clock: Clock = MillisClock()
  public private(set) var resource: Resource = .init()
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

  public func registerMetricReader(reader: MetricReader) -> MeterProviderBuilder {
    let newBuilder = MeterProviderBuilder()
      .setClock(clock: clock)
      .setResource(resource: resource)
      .registerMetricReader(reader: reader)
      .setExemplarFilter(exemplarFilter: exemplarFilter)
    for view in registeredViews {
      _ = newBuilder.registerView(selector: view.selector, view: view.view)
    }
    return newBuilder
  }

  public func setExemplarFilter(exemplarFilter: ExemplarFilter) -> Self {
    self.exemplarFilter = exemplarFilter
    return self
  }

  public func build() -> DefaultMeterProvider {
    DefaultMeterProvider.instance
  }
}
