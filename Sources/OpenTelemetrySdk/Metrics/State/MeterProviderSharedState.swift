//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class MeterProviderSharedState {
  public init(clock: Clock, resource: Resource, startEpochNanos: UInt64, exemplarFilter: ExemplarFilter) {
    self.clock = clock
    self.resource = resource
    self.startEpochNanos = startEpochNanos
    self.exemplarFilter = exemplarFilter
  }

  public private(set) var clock: Clock
  public private(set) var resource: Resource
  public private(set) var startEpochNanos: UInt64
  public private(set) var exemplarFilter: ExemplarFilter
}
