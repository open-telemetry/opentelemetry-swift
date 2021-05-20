/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public struct Metric {
    public private(set) var namespace: String
    public private(set) var resource: Resource
    public private(set) var instrumentationLibraryInfo : InstrumentationLibraryInfo
    public private(set) var name: String
    public private(set) var description: String
    public private(set) var aggregationType: AggregationType
    public internal(set) var data = [MetricData]()

    init(namespace: String, name: String, desc: String, type: AggregationType, resource: Resource, instrumentationLibraryInfo: InstrumentationLibraryInfo) {
        self.namespace = namespace
        self.instrumentationLibraryInfo = instrumentationLibraryInfo
        self.name = name
        description = desc
        aggregationType = type
        self.resource = resource
    }
}
