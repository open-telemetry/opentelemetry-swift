//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi


class NoopAttributesProccessor : AnyAttributesProcessor {
    func process(attributes: [String : OpenTelemetryApi.AttributeValue]) {
        return attributes
    }
    
    
    public static let noop = NoopAttributesProccessor()
    
}
