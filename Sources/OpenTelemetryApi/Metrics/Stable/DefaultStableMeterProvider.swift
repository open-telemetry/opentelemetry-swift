//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class DefaultStableMeterProvider: StableMeterProvider {
  static let noopMeterBuilder = NoopMeterBuilder()
  
  public static func noop() -> MeterBuilder {
    noopMeterBuilder
  }
  
  public func get(name: String) -> StableMeter {
    DefaultStableMeter()
  }
  
  public func meterBuilder(name: String) -> MeterBuilder {
    Self.noop()
  }
      
  class NoopMeterBuilder : MeterBuilder {
    static let noopMeter = DefaultStableMeter()

    func setSchemaUrl(schemaUrl: String) -> Self {
      self
    }
    
    func setInstrumentationVersion(instrumentationVersion: String) -> Self {
      self
    }
    
    func build() -> StableMeter {
      Self.noopMeter
    }
    
  }
    
    public static var instance : StableMeterProvider = DefaultStableMeterProvider()
}
