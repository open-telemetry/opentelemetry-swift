//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi

public class ExemplarData: Equatable {
    internal init(epochNanos: UInt64, filteredAttributes: [String: AttributeValue], spanContext: SpanContext? = nil) {
        self.filteredAttributes = filteredAttributes
        self.epochNanos = epochNanos
        self.spanContext = spanContext
    }

    public var filteredAttributes: [String: AttributeValue]
    public var epochNanos: UInt64
    public var spanContext: OpenTelemetryApi.SpanContext?

    public static func == (lhs: ExemplarData, rhs: ExemplarData) -> Bool {
        return type(of: lhs) == type(of: rhs) && lhs.isEqual(to: rhs)
    }

    func isEqual(to other: ExemplarData) -> Bool {
        return self.epochNanos == other.epochNanos &&
            self.spanContext == other.spanContext &&
            self.filteredAttributes == other.filteredAttributes
    }
}

public final class DoubleExemplarData: ExemplarData {
    public var value: Double

    internal init(value: Double, epochNanos: UInt64, filteredAttributes: [String: AttributeValue], spanContext: SpanContext? = nil) {
        self.value = value
        super.init(epochNanos: epochNanos, filteredAttributes: filteredAttributes, spanContext: spanContext)
    }

    override func isEqual(to other: ExemplarData) -> Bool {
        return self.value == (other as! DoubleExemplarData).value &&
            super.isEqual(to: other)
    }
}

public final class LongExemplarData: ExemplarData {
    public var value: Int
    internal init(value: Int, epochNanos: UInt64, filteredAttributes: [String: AttributeValue], spanContext: SpanContext? = nil) {
        self.value = value
        super.init(epochNanos: epochNanos, filteredAttributes: filteredAttributes, spanContext: spanContext)
    }

    override func isEqual(to other: ExemplarData) -> Bool {
        return self.value == (other as! LongExemplarData).value &&
            super.isEqual(to: other)
    }
}
