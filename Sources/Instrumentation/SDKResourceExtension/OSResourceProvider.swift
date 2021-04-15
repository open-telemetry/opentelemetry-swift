// Copyright 2021, OpenTelemetry Authors
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
import OpenTelemetryApi
import OpenTelemetrySdk

public class OSResourceProvider: ResourceProvider {
    let osDataSource: IOperatingSystemDataSource

    public init(source: IOperatingSystemDataSource) {
        osDataSource = source
    }

    override public var attributes: [String: AttributeValue] {
        var attributes = [String: AttributeValue]()

        attributes[ResourceAttributes.osType.rawValue] = AttributeValue.string(osDataSource.type)
        attributes[ResourceAttributes.osDescription.rawValue] = AttributeValue.string(osDataSource.description)

        return attributes
    }
}
