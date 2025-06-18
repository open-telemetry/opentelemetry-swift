//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public protocol ExemplarFilter {
  func shouldSampleMeasurement(value: Int, attributes: [String: AttributeValue]) -> Bool
  func shouldSampleMeasurement(value: Double, attributes: [String: AttributeValue]) -> Bool
}

public struct AlwaysOnFilter: ExemplarFilter {
  public init() {}

  public func shouldSampleMeasurement(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Bool {
    return true
  }

  public func shouldSampleMeasurement(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Bool {
    return true
  }
}

public struct AlwaysOffFilter: ExemplarFilter {
  public init() {}

  public func shouldSampleMeasurement(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Bool {
    false
  }

  public func shouldSampleMeasurement(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Bool {
    false
  }
}

public struct TraceBasedFilter: ExemplarFilter {
  public init() {}

  public func shouldSampleMeasurement(value: Int, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Bool {
    hasSampledTrace()
  }

  public func shouldSampleMeasurement(value: Double, attributes: [String: OpenTelemetryApi.AttributeValue]) -> Bool {
    hasSampledTrace()
  }

  private func hasSampledTrace() -> Bool {
    OpenTelemetry.instance.contextProvider.activeSpan?.context.isSampled ?? false
  }
}
