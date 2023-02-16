//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi

protocol ValueAtQuantile {
    func quantile() -> Double
    func value() -> Double
}
