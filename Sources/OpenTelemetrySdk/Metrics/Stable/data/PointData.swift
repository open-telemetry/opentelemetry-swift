//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class PointData {
    internal init(startEpochNanos: UInt64, endEpochNanos: UInt64, attributes: [String: AttributeValue], exemplars: [ExemplarData]) {
        self.startEpochNanos = startEpochNanos
        self.endEpochNanos = endEpochNanos
        self.attributes = attributes
        self.exemplars = exemplars
    }

    public var startEpochNanos: UInt64
    public var endEpochNanos: UInt64
    public var attributes: [String: OpenTelemetryApi.AttributeValue]
    public var exemplars: [ExemplarData]
    public static func - (left: PointData, right: PointData) -> Self {
        return left as! Self
    }
}
