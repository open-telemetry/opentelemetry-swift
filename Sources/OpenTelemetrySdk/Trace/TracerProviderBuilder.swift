/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetryApi

public class TracerProviderBuilder {
    public private(set) var clock : Clock = MillisClock()
    public private(set) var idGenerator : IdGenerator = RandomIdGenerator()
    public private(set) var resource : Resource = Resource()
    public private(set) var spanLimits : SpanLimits = SpanLimits()
    public private(set) var sampler : Sampler = Samplers.parentBased(root: Samplers.alwaysOn)
    public private(set) var spanProcessors : [SpanProcessor] = []

    public init() {}

    public func with(clock: Clock) -> Self {
        self.clock = clock
        return self
    }

    public func with(idGenerator: IdGenerator) -> Self {
        self.idGenerator = idGenerator
        return self
    }

    public func with(resource: Resource) -> Self {
        self.resource = resource
        return self
    }
    public func with(spanLimits: SpanLimits) -> Self {
        self.spanLimits = spanLimits
        return self
    }

    public func with(sampler: Sampler) -> Self {
        self.sampler = sampler
        return self
    }

    public func add(spanProcessor: SpanProcessor) -> Self {
        spanProcessors.append(spanProcessor)
        return self
    }

    public func add(spanProcessors: [SpanProcessor]) -> Self {
        self.spanProcessors.append(contentsOf: spanProcessors)
        return self
    }

    public func build() -> TracerProviderSdk {
        return TracerProviderSdk(clock: clock, idGenerator: idGenerator, resource: resource, spanLimits: spanLimits, sampler: sampler, spanProcessors: spanProcessors)
    }
}
