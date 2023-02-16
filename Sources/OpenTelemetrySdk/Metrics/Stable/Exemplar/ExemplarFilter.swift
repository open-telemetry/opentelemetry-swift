//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol ExemplarFilter {
    func shouldSampleMeasurement(value: Int, attributes: [String: AttributeValue]) -> Bool
    func shouldSampleMeasurement(value: Double, attributes: [String: AttributeValue]) -> Bool
}

public class AlwaysOnFilter : ExemplarFilter {
    public func shouldSampleMeasurement(value: Double, attributes: [String : OpenTelemetryApi.AttributeValue]) -> Bool {
        return true
    }
    
    public func shouldSampleMeasurement(value: Int, attributes: [String : OpenTelemetryApi.AttributeValue]) -> Bool {
        return true
    }
    
    
}
