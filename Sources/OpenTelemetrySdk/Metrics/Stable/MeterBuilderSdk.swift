//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public class MeterBuilderSdk : MeterBuilder {
    
    private let registry : ComponentRegistry<StableMeterSdk>
    private let instrumentationScopeName : String
    private var instrumentationVersion : String?
    private var schemaUrl : String?
    
    internal init(registry: ComponentRegistry<StableMeterSdk>, instrumentationScopeName: String) {
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
    
    public func build() -> OpenTelemetryApi.StableMeter {
        return registry.get(name: instrumentationScopeName, version: instrumentationVersion, schemaUrl: schemaUrl)
    }
    
    
}
