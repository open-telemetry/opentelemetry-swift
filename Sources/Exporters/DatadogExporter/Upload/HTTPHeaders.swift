/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// HTTP headers associated with requests send by SDK.
internal struct HTTPHeaders {
    enum ContentType: String {
        case applicationJSON = "application/json"
        case textPlainUTF8 = "text/plain;charset=UTF-8"
    }

    struct HTTPHeader {
        let field: String
        let value: String

        // MARK: - Supported headers

        static func contentTypeHeader(contentType: ContentType) -> HTTPHeader {
            return HTTPHeader(field: "Content-Type", value: contentType.rawValue)
        }

        static func compressedContentEncodingHeader() -> HTTPHeader {
            return HTTPHeader( field: "Content-Encoding", value: "gzip")
        }

        static func userAgentHeader(appName: String, appVersion: String, device: Device) -> HTTPHeader {
            return HTTPHeader(
                field: "User-Agent",
                value: "\(appName)/\(appVersion) CFNetwork (\(device.model); \(device.osName)/\(device.osVersion))"
            )
        }

        static func applicationKeyHeader(applicationKey: String) -> HTTPHeader {
            return HTTPHeader(field: "DD-APPLICATION-KEY", value: applicationKey)
        }

        // MARK: - Initialization

        private init(field: String, value: String) {
            self.field = field
            self.value = value
        }
    }

    let all: [String: String]

    init(headers: [HTTPHeader]) {
        self.all = headers.reduce([:]) { acc, next in
            var dictionary = acc
            dictionary[next.field] = next.value
            return dictionary
        }
    }
}
