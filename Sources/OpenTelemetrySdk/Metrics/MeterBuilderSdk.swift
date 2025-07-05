//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class MeterBuilderSdk: MeterBuilder {
  private let registry: ComponentRegistry<StableMeterSdk>
  private let instrumentationScopeName: String
  private var instrumentationVersion: String?
  private var attributes: [String: AttributeValue]?
  private var schemaUrl: String?

  init(registry: ComponentRegistry<StableMeterSdk>, instrumentationScopeName: String) {
    self.registry = registry
    self.instrumentationScopeName = instrumentationScopeName
  }

  public func setSchemaUrl(schemaUrl: String) -> Self {
    self.schemaUrl = schemaUrl
    return self
  }

  public func setInstrumentationVersion(instrumentationVersion: String) -> Self {
    self.instrumentationVersion = instrumentationVersion
    return self
  }

  public func setAttributes(attributes: [String: OpenTelemetryApi.AttributeValue]) -> Self {
    self.attributes = attributes
    return self
  }

  public func build() -> StableMeterSdk {
    return registry.get(name: instrumentationScopeName, version: instrumentationVersion, schemaUrl: schemaUrl)
  }
}
