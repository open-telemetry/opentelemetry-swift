//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class NoopObservableLongMeasurement: ObservableLongMeasurement {
  public func record(value: Int) {}
  public func record(value: Int, attributes: [String: AttributeValue]) {}
}

public class NoopObservableDoubleMeasurement: ObservableDoubleMeasurement {
  public func record(value: Double) {}
  public func record(value: Double, attributes: [String: AttributeValue]) {}
}

public class DefaultMeter: Meter, @unchecked Sendable {
  init() {}

  public func counterBuilder(name: String) -> NoopLongCounterBuilder {
    NoopLongCounterBuilder()
  }

  public func upDownCounterBuilder(name: String) -> NoopLongUpDownCounterBuilder {
    NoopLongUpDownCounterBuilder()
  }

  public func histogramBuilder(name: String) -> NoopDoubleHistogramBuilder {
    NoopDoubleHistogramBuilder()
  }

  public func gaugeBuilder(name: String) -> NoopDoubleGaugeBuilder {
    NoopDoubleGaugeBuilder()
  }

  public class NoopLongUpDownCounterBuilder: LongUpDownCounterBuilder {
    public func ofDoubles() -> NoopDoubleUpDownCounterBuilder {
      NoopDoubleUpDownCounterBuilder()
    }

    public func build() -> NoopLongUpDownCounter {
      NoopLongUpDownCounter()
    }

    public func buildWithCallback(_ callback: @escaping (NoopObservableLongMeasurement) -> Void) -> NoopObservableLongUpDownCounter {
      NoopObservableLongUpDownCounter()
    }
  }

  public class NoopDoubleHistogramBuilder: DoubleHistogramBuilder {
    public func setExplicitBucketBoundariesAdvice(_ boundaries: [Double]) -> Self {
      return self
    }

    public func ofLongs() -> NoopLongHistogramBuilder {
      NoopLongHistogramBuilder()
    }

    public func build() -> NoopDoubleHistogram {
      NoopDoubleHistogram()
    }
  }

  public class NoopDoubleGaugeBuilder: DoubleGaugeBuilder {
    public func ofLongs() -> NoopLongGaugeBuilder {
      NoopLongGaugeBuilder()
    }

    public func build() -> NoopDoubleGauge {
      NoopDoubleGauge()
    }

    public func buildWithCallback(_ callback: @escaping (NoopObservableDoubleMeasurement) -> Void) -> NoopObservableDoubleGauge {
      NoopObservableDoubleGauge()
    }
  }

  public class NoopLongGaugeBuilder: LongGaugeBuilder {
    public func build() -> NoopLongGauge {
      NoopLongGauge()
    }

    public func buildWithCallback(_ callback: @escaping (NoopObservableLongMeasurement) -> Void) -> NoopObservableLongGauge {
      NoopObservableLongGauge()
    }
  }

  public struct NoopDoubleGauge: DoubleGauge {
    public func record(value: Double) {}

    public func record(value: Double, attributes: [String: AttributeValue]) {}
  }

  public struct NoopLongGauge: LongGauge {
    public func record(value: Int) {}

    public func record(value: Int, attributes: [String: AttributeValue]) {}
  }

  public struct NoopObservableLongGauge: ObservableLongGauge {
    public func close() {}
  }

  public struct NoopObservableDoubleGauge: ObservableDoubleGauge {
    public func close() {}
  }

  public class NoopDoubleUpDownCounterBuilder: DoubleUpDownCounterBuilder {
    public func build() -> NoopDoubleUpDownCounter {
      NoopDoubleUpDownCounter()
    }

    public func buildWithCallback(_ callback: @escaping (NoopObservableDoubleMeasurement) -> Void) -> NoopObservableDoubleUpDownCounter {
      NoopObservableDoubleUpDownCounter()
    }
  }

  public struct NoopObservableDoubleUpDownCounter: ObservableDoubleUpDownCounter {
    public func close() {}
  }

  public struct NoopDoubleUpDownCounter: DoubleUpDownCounter {
    public mutating func add(value: Double) {}
    public mutating func add(value: Double, attributes: [String: AttributeValue]) {}
  }

  public class NoopLongUpDownCounter: LongUpDownCounter {
    public func add(value: Int) {}
    public func add(value: Int, attributes: [String: AttributeValue]) {}
  }

  public class NoopLongHistogramBuilder: LongHistogramBuilder {
    public func setExplicitBucketBoundariesAdvice(_ boundaries: [Double]) -> Self {
      return self
    }

    public func build() -> NoopLongHistogram {
      NoopLongHistogram()
    }
  }

  public struct NoopLongHistogram: LongHistogram {
    public mutating func record(value: Int) {}
    public mutating func record(value: Int, attributes: [String: AttributeValue]) {}
  }

  public class NoopObservableLongUpDownCounter: ObservableLongUpDownCounter {
    public func close() {}
  }

  public class NoopDoubleHistogram: DoubleHistogram {
    public func record(value: Double) {}
    public func record(value: Double, attributes: [String: AttributeValue]) {}
  }

  public class NoopLongCounter: LongCounter {
    public func add(value: Int) {}
    public func add(value: Int, attributes: [String: AttributeValue]) {}
  }

  public class NoopLongCounterBuilder: LongCounterBuilder {
    public func ofDoubles() -> NoopDoubleCounterBuilder {
      NoopDoubleCounterBuilder()
    }

    public func build() -> NoopLongCounter {
      NoopLongCounter()
    }

    public func buildWithCallback(_ callback: @escaping (NoopObservableLongMeasurement) -> Void) -> NoopObservableLongCounter {
      NoopObservableLongCounter()
    }
  }

  public class NoopDoubleCounterBuilder: DoubleCounterBuilder {
    public func build() -> NoopDoubleCounter {
      NoopDoubleCounter()
    }

    public func buildWithCallback(_ callback: @escaping (NoopObservableDoubleMeasurement) -> Void) -> NoopObservableDoubleCounter {
      NoopObservableDoubleCounter()
    }
  }

  public class NoopObservableLongCounter: ObservableLongCounter {
    public func close() {}
  }

  public class NoopObservableDoubleCounter: ObservableDoubleCounter {
    public func close() {}
  }

  @available(*, deprecated, renamed: "NoopDoubleCounterBuilder")
  public typealias StableNoopDoubleCounterBuilder = NoopDoubleCounterBuilder

  @available(*, deprecated, renamed: "NoopDoubleCounter")
  public typealias StableNoopDoubleCounter = NoopDoubleCounter

  public class NoopDoubleCounter: DoubleCounter {
    public func add(value: Double) {}
    public func add(value: Double, attributes: [String: AttributeValue]) {}
  }
}
