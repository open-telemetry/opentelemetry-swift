//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation

public enum InstrumentType: CaseIterable {
    case counter
    case upDownCounter
    case histogram
    case observableCounter
    case observableUpDownCounter
    case observableGauge
}
