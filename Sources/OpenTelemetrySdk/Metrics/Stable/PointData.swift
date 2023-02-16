//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

public protocol PointData {
    func getStartEpochNanos() -> Int
    func getEndEpochNanos() -> Int
    func attributes() -> [String: AttributeValue]
    func exemplars() -> [ExemplarData]
}
