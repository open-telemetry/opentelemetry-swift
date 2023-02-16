//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public protocol LongPointData : PointData {
    func value() -> Int
    func exemplars() -> [LongExemplarData]

}

public protocol DoublePointData : PointData {
    func value() -> Double
    func exemplars() -> [DoubleExemplarData]
}

public protocol SummaryPointData : PointData {
    func count() -> Int
    func sum() -> Double
    func values() -> [ValueAtQuantile]
}


public protocol HistogramPointData : PointData {
    func sum() -> Double
    func count() -> Double
    func hasMin() -> Bool
    func hasMax() -> Bool
    func max() -> Double
    func min() -> Double
    func boundries() -> [Double]
    func counts() -> [Int]
    func exemplars() -> [DoubleExemplarData]
}
