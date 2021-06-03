/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public enum AggregationType {
    case intGauge
    case doubleGauge
    case doubleSum
    case intSum
    case doubleSummary
    case intSummary
}
