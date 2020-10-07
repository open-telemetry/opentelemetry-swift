// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

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

        static func userAgentHeader(appName: String, appVersion: String, device: Device) -> HTTPHeader {
            return HTTPHeader(
                field: "User-Agent",
                value: "\(appName)/\(appVersion) CFNetwork (\(device.model); \(device.osName)/\(device.osVersion))"
            )
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
