//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class DefaultStableMeterProvider: StableMeterProvider {
  static let noopMeterBuilder = NoopMeterBuilder()

  public static func noop() -> NoopMeterBuilder {
    noopMeterBuilder
  }

  public func get(name: String) -> DefaultStableMeter {
    NoopMeterBuilder.noopMeter
  }

  public func meterBuilder(name: String) -> NoopMeterBuilder {
    Self.noop()
  }

  public class NoopMeterBuilder: MeterBuilder {
    static let noopMeter = DefaultStableMeter()

    public func setSchemaUrl(schemaUrl: String) -> Self {
      self
    }

    public func setInstrumentationVersion(instrumentationVersion: String) -> Self {
      self
    }

    public func setAttributes(attributes: [String: AttributeValue]) -> Self {
      self
    }

    public func build() -> DefaultStableMeter {
      Self.noopMeter
    }
  }

  public static var instance = DefaultStableMeterProvider()
}
