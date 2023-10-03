//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public class DefaultStableMeter : StableMeter {
  
  internal init() {}
  
  public func counterBuilder(name: String) -> LongCounterBuilder {
    NoopLongCounterBuilder()
  }
  
  public func upDownCounterBuilder(name: String) -> LongUpDownCounterBuilder {
    NoopLongUpDownCounterBuilder()
  }
  
  public func histogramBuilder(name: String) -> DoubleHistogramBuilder {
    NoopDoubleHistogramBuilder()
  }
  
  public func gaugeBuilder(name: String) -> DoubleGaugeBuilder {
    NoopDoubleGaugeBuilder()
  }
  
  private class NoopLongUpDownCounterBuilder : LongUpDownCounterBuilder {
    func ofDoubles() -> DoubleUpDownCounterBuilder {
      NoopDoubleUpDownCounterBuilder()
    }
    
    func build() -> LongUpDownCounter {
      NoopLongUpDownCounter()
    }
    
    func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongUpDownCounter {
      NoopObservableLongUpDownCounter()
    }
  }
  
  private class NoopDoubleHistogramBuilder : DoubleHistogramBuilder {
    func ofLongs() -> LongHistogramBuilder {
      NoopLongHistogramBuilder()
    }
    
    func build() -> DoubleHistogram {
      NoopDoubleHistogram()
    }
  }
  
  private class NoopDoubleGaugeBuilder : DoubleGaugeBuilder {
    func ofLongs() -> LongGaugeBuilder {
      NoopLongGaugeBuilder()
    }
    
    func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement) -> Void) -> ObservableDoubleGauge {
      NoopObservableDoubleGauge()
    }
  }
  
  private class NoopLongGaugeBuilder : LongGaugeBuilder {
    func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongGauge {
        NoopObservableLongGauge()
    }
  }
  
  private struct NoopObservableLongGauge : ObservableLongGauge {
      func close() {}
  }
  
  private struct NoopObservableDoubleGauge : ObservableDoubleGauge {
      func close() {}
  }
  
  private class NoopDoubleUpDownCounterBuilder : DoubleUpDownCounterBuilder {
    func build() -> DoubleUpDownCounter {
      NoopDoubleUpDownCounter()
    }
    
    func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement) -> Void) -> ObservableDoubleUpDownCounter {
      NoopObservableDoubleUpDownCounter()
    }
  }
  
  private struct NoopObservableDoubleUpDownCounter : ObservableDoubleUpDownCounter {
      func close() {}
  }
  
  private struct NoopDoubleUpDownCounter : DoubleUpDownCounter {
    mutating func add(value: Double) {}
    mutating func add(value: Double, attributes: [String : AttributeValue]) {}
  }
  
  private class NoopLongUpDownCounter : LongUpDownCounter {
    func add(value: Int) {}
    func add(value: Int, attributes: [String : AttributeValue]) {}
  }
  
  private class NoopLongHistogramBuilder : LongHistogramBuilder {
    func build() -> LongHistogram {
      NoopLongHistogram()
    }
  }
  
  private struct NoopLongHistogram : LongHistogram {
    mutating func record(value: Int) {}
    mutating func record(value: Int, attributes: [String : AttributeValue]) {}
  }
  
  private class NoopObservableLongUpDownCounter : ObservableLongUpDownCounter {
      func close() {}
  }
  
  private class NoopDoubleHistogram : DoubleHistogram {
    func record(value: Double) {}
    func record(value: Double, attributes: [String : AttributeValue]) {}
  }
  
  private class NoopLongCounter : LongCounter {
    func add(value: Int) {}
    func add(value: Int, attribute: [String : AttributeValue]) {}
  }
  
  private class NoopLongCounterBuilder : LongCounterBuilder {
    func ofDoubles() -> DoubleCounterBuilder {
      NoopDoubleCounterBuilder()
    }
    
    func build() -> LongCounter {
      NoopLongCounter()
    }
    
    func buildWithCallback(_ callback: @escaping (ObservableLongMeasurement) -> Void) -> ObservableLongCounter {
      NoopObservableLongCounter()
    }
  }
  
  private class NoopDoubleCounterBuilder : DoubleCounterBuilder {
    func build() -> DoubleCounter {
      StableNoopDoubleCounter()
    }
    
    func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement) -> Void) -> ObservableDoubleCounter {
      NoopObservableDoubleCounter()
    }
  }
  
  private class NoopObservableLongCounter : ObservableLongCounter {
      func close() {}
  }
    
  private class NoopObservableDoubleCounter: ObservableDoubleCounter {
      func close() {}
  }

  private class StableNoopDoubleCounterBuilder : DoubleCounterBuilder {
    func build() -> DoubleCounter {
      StableNoopDoubleCounter()
    }
    
    func buildWithCallback(_ callback: @escaping (ObservableDoubleMeasurement) -> Void) -> ObservableDoubleCounter {
      NoopObservableDoubleCounter()
    }
  }
  
  private class StableNoopDoubleCounter : DoubleCounter {
    func add(value: Double) {}
    func add(value: Double, attributes: [String : AttributeValue]) {}
  }
}






