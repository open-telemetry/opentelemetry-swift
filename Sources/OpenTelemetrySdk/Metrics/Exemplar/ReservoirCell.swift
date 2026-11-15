//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class ReservoirCell {
  let clock: Clock
  let attributes = ReadWriteLocked<[String: AttributeValue]>(initialValue: [:])
  var spanContext: SpanContext?
  var recordTime: UInt64 = 0

  var doubleValue: Double = 0
  var longValue: Int = 0

  init(clock: Clock) {
    self.clock = clock
  }

  func recordLongValue(value: Int, attributes: [String: AttributeValue]) {
    longValue = value
    offerMeasurement(attributes: attributes)
  }

  func recordDoubleValue(value: Double, attributes: [String: AttributeValue]) {
    doubleValue = value
    offerMeasurement(attributes: attributes)
  }

  private func offerMeasurement(attributes: [String: AttributeValue]) {
    self.attributes.protectedValue = attributes
    recordTime = clock.nanoTime
    if let context = OpenTelemetry.instance.contextProvider.activeSpan?.context, context.isValid {
      spanContext = context
    }
  }

  func getAndResetLong(pointAttributes: [String: AttributeValue]) -> LongExemplarData? {
      let result: LongExemplarData? = attributes.readLocking {
      if $0.isEmpty {
        return nil
      }
      return LongExemplarData(value: longValue, epochNanos: recordTime, filteredAttributes: filtered($0, pointAttributes), spanContext: spanContext)
    }
    reset()
    return result
  }

  func getAndResetDouble(pointAttributes: [String: AttributeValue]) -> DoubleExemplarData? {
    let result: DoubleExemplarData? = attributes.readLocking {
      if $0.isEmpty {
        return nil
      }
      return DoubleExemplarData(value: doubleValue, epochNanos: recordTime, filteredAttributes: filtered($0, pointAttributes), spanContext: spanContext)
    }
    reset()
    return result
  }

  func reset() {
    attributes.protectedValue = [String: AttributeValue]()
    longValue = 0
    doubleValue = 0
    spanContext = nil
    recordTime = 0
  }

  func filtered(_ original: [String: AttributeValue], _ metricPoint: [String: AttributeValue]) -> [String: AttributeValue] {
    if metricPoint.isEmpty {
      return original
    }
    return original.filter { key, _ in
      if metricPoint[key] != nil {
        return false
      }
      return true
    }
  }
}
