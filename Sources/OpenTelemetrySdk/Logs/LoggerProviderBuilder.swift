//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation


public class LoggerProviderBuilder {
    public private(set) var clock : Clock = MillisClock()
    public private(set) var resource : Resource = Resource()
    public private(set) var logLimits : LogLimits = LogLimits()
    public private(set) var logProcessors : [LogRecordProcessor] = []
    
    public init() {
    }
    
    public func with(clock: Clock) -> Self {
        self.clock = clock
        return self
    }
    
    public func with(resource: Resource) -> Self {
        self.resource = resource
        return self
    }
    
    public func with(logLimits: LogLimits) -> Self {
        self.logLimits = logLimits
        return self
    }
    
    public func with(processors: [LogRecordProcessor]) -> Self {
        logProcessors.append(contentsOf:processors)
        return self
    }
    
    public func build() -> LoggerProviderSdk {
        return LoggerProviderSdk(clock: clock, resource: resource, logLimits: logLimits, logRecordProcessors: logProcessors)
    }
}
