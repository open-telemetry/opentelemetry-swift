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

class ZipkinEndpoint: Encodable {
    var serviceName: String
    var ipv4: String?
    var ipv6: String?
    var port: Int?

    public init(serviceName: String, ipv4: String? = nil, ipv6: String? = nil, port: Int? = nil) {
        self.serviceName = serviceName
        self.ipv4 = ipv4
        self.ipv6 = ipv6
        self.port = port
    }

    public func clone(serviceName: String) -> ZipkinEndpoint {
        return ZipkinEndpoint(serviceName: serviceName, ipv4: ipv4, ipv6: ipv6, port: port)
    }

    public func write() -> [String: Any] {
        var output = [String: Any]()

        output["serviceName"] = serviceName
        output["ipv4"] = ipv4
        output["ipv6"] = ipv6
        output["port"] = port

        return output
    }
}
