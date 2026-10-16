/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// DefaultContextPropagators  is the default, built-in implementation of ContextPropagators
/// All the registered propagators are stored internally as a simple list, and are invoked
/// synchronically upon injection and extraction.
public struct DefaultContextPropagators: ContextPropagators {
  public var textMapPropagator: TextMapPropagator
  public var textMapBaggagePropagator: TextMapBaggagePropagator

  public init() {
    textMapPropagator = NoopTextMapPropagator()
    textMapBaggagePropagator = NoopBaggagePropagator()
  }

  public init(textPropagators: [TextMapPropagator], baggagePropagator: TextMapBaggagePropagator) {
    textMapPropagator = MultiTextMapPropagator(textPropagators: textPropagators)
    textMapBaggagePropagator = baggagePropagator
  }

  public mutating func addTextMapPropagator(textFormat: TextMapPropagator) {
    if textMapPropagator is NoopTextMapPropagator {
      textMapPropagator = textFormat
    } else if var multiFormat = textMapPropagator as? MultiTextMapPropagator {
      multiFormat.textPropagators.append(textFormat)
    } else {
      textMapPropagator = MultiTextMapPropagator(textPropagators: [textMapPropagator])
      if var multiFormat = textMapPropagator as? MultiTextMapPropagator {
        multiFormat.textPropagators.append(textFormat)
      }
    }
  }

  struct MultiTextMapPropagator: TextMapPropagator {
    public var fields: Set<String>
    var textPropagators = [TextMapPropagator]()

    init(textPropagators: [TextMapPropagator]) {
      self.textPropagators = textPropagators
      fields = MultiTextMapPropagator.getAllFields(textPropagators: self.textPropagators)
    }

    private static func getAllFields(textPropagators: [TextMapPropagator]) -> Set<String> {
      var fields = Set<String>()
      textPropagators.forEach {
        fields.formUnion($0.fields)
      }
      return fields
    }

    public func inject(spanContext: SpanContext, carrier: inout [String: String], setter: some Setter) {
      textPropagators.forEach {
        $0.inject(spanContext: spanContext, carrier: &carrier, setter: setter)
      }
    }

    public func extract(carrier: [String: String], getter: some Getter) -> SpanContext? {
      var spanContext: SpanContext?
      textPropagators.forEach {
        spanContext = $0.extract(carrier: carrier, getter: getter)
      }
      return spanContext
    }
  }

  struct NoopTextMapPropagator: TextMapPropagator {
    public var fields = Set<String>()

    public func inject(spanContext: SpanContext, carrier: inout [String: String], setter: some Setter) {}

    public func extract(carrier: [String: String], getter: some Getter) -> SpanContext? {
      return nil
    }
  }

  struct NoopBaggagePropagator: TextMapBaggagePropagator {
    public var fields = Set<String>()

    public func inject(baggage: Baggage, carrier: inout [String: String], setter: some Setter) {}

    public func extract(carrier: [String: String], getter: some Getter) -> Baggage? {
      return nil
    }
  }
}
