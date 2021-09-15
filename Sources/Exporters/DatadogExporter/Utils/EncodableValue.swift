/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Type erasure `Encodable` wrapper.
internal struct EncodableValue: Encodable {
    let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        if let urlValue = value as? URL {
            /**
             "URL itself prefers a keyed container which allows it to encode its base and relative string separately (...)"
             Discussion: https:forums.swift.org/t/how-to-encode-objects-of-unknown-type/12253/11

             It means that following code:
             ```
             try EncodableValue(URL(string: "https:example.com")!).encode(to: encoder)
             ```
             encodes the KVO representation of the URL: `{"relative":"https:example.com"}`.
             As we very much prefer `"https:example.com"`, here we switch to encode `.absoluteString` directly.
             */
            try urlValue.absoluteString.encode(to: encoder)
        } else {
            try value.encode(to: encoder)
        }
    }
}

/// Value type converting any `Encodable` to its lossless JSON string representation.
///
/// For example:
/// * it encodes `"abc"` string as `"abc"` JSON string value
/// * it encodes `1` integer as `"1"` JSON string value
/// * it encodes `true` boolean as `"true"` JSON string value
/// * it encodes `Person(name: "foo")` encodable struct as `"{\"name\": \"foo\"}"` JSON string value
///
/// This encoding doesn't happen instantly. Instead, it is deferred to the actual `encoder.encode(jsonStringEncodableValue)` call.
internal struct JSONStringEncodableValue: Encodable {
    /// Encoder used to encode `encodable` as JSON String value.
    /// It is invoked lazily at `encoder.encode(jsonStringEncodableValue)` so its encoding errors can be propagated in master-type encoding.
    private let jsonEncoder: JSONEncoder
    private let encodable: EncodableValue

    init(_ value: Encodable, encodedUsing jsonEncoder: JSONEncoder) {
        self.jsonEncoder = jsonEncoder
        self.encodable = EncodableValue(value)
    }

    func encode(to encoder: Encoder) throws {
        if let stringValue = encodable.value as? String {
            try stringValue.encode(to: encoder)
        } else if let urlValue = encodable.value as? URL {
            // Switch to encode `url.absoluteString` directly - see the comment in `EncodableValue`
            try urlValue.absoluteString.encode(to: encoder)
        } else {
            let jsonData: Data

            if #available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
                jsonData = try jsonEncoder.encode(encodable)
            } else {
                // Prior to `iOS13.0` the `JSONEncoder` is unable to encode primitive values - it expects them to be
                // wrapped inside top-level JSON object (array or dictionary). Reference: https://bugs.swift.org/browse/SR-6163
                //
                // As a workaround, we serialize the `encodable` as a JSON array and then remove `[` and `]` bytes from serialized data.
                let temporaryJsonArrayData = try jsonEncoder.encode([encodable])

                let subdataStartIndex = temporaryJsonArrayData.startIndex.advanced(by: 1)
                let subdataEndIndex = temporaryJsonArrayData.endIndex.advanced(by: -1)

                guard subdataStartIndex < subdataEndIndex else {
                    // This error should never be thrown, as the `temporaryJsonArrayData` will always contain at
                    // least two bytes standing for `[` and `]`. This check is just for sanity.
                    let encodingContext = EncodingError.Context(
                        codingPath: encoder.codingPath,
                        debugDescription: "Cannot safely encode value within a temporary array container."
                    )
                    throw EncodingError.invalidValue(encodable.value, encodingContext)
                }

                jsonData = temporaryJsonArrayData.subdata(in: subdataStartIndex..<subdataEndIndex)
            }

            if let stringValue = String(data: jsonData, encoding: .utf8) {
                try stringValue.encode(to: encoder)
            }
        }
    }
}
