//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi


class NoopAttributesProccessor : AttributeProcessorProtocol {

  func process(incoming attributes: [String : OpenTelemetryApi.AttributeValue]) ->  [String: OpenTelemetryApi.AttributeValue] {
        return attributes
    }

    public static let noop = NoopAttributesProccessor()
}
