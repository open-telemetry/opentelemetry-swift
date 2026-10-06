//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation

@available(*, deprecated, renamed: "DefaultMeterProvider")
public typealias DefaultStableMeterProvider = DefaultMeterProvider

public class DefaultMeterProvider: MeterProvider, @unchecked Sendable {
  static let noopMeterBuilder = NoopMeterBuilder()

  public static func noop() -> NoopMeterBuilder {
    noopMeterBuilder
  }

  public func get(name: String) -> DefaultMeter {
    NoopMeterBuilder.noopMeter
  }

  public func meterBuilder(name: String) -> NoopMeterBuilder {
    Self.noop()
  }

  public class NoopMeterBuilder: MeterBuilder, @unchecked Sendable {
    static let noopMeter = DefaultMeter()

    public func setSchemaUrl(schemaUrl: String) -> Self {
      self
    }

    public func setInstrumentationVersion(instrumentationVersion: String) -> Self {
      self
    }

    public func setAttributes(attributes: [String: AttributeValue]) -> Self {
      self
    }

    public func build() -> DefaultMeter {
      Self.noopMeter
    }
  }

  public static let instance = DefaultMeterProvider()
}
