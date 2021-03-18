/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import OpenTelemetryApi

internal class HTTPHeadersReader : Getter {
    private let httpHeaderFields: [String: String]
    private var baggageItemQueue: DispatchQueue?

    init(httpHeaderFields: [String: String]) {
        self.httpHeaderFields = httpHeaderFields
    }

    func use(baggageItemQueue: DispatchQueue) {
        self.baggageItemQueue = baggageItemQueue
    }

    func extract() -> SpanContext? {
        return W3CTraceContextPropagator().extract(carrier: httpHeaderFields, getter: self)
    }


    public func get(carrier: [String: String], key: String) -> [String]? {
        guard let value = carrier[key] else {
            return nil
        }
        return [value]

    }
}
