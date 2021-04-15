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

public class ApplicationResourceProvider: ResourceProvider {
    let applicationDataSource: IApplicationDataSource

    public init(source: IApplicationDataSource) {
        applicationDataSource = source
    }

    override public var attributes: [String: AttributeValue] {
        var attributes = [String: AttributeValue]()

        if let bundleName = applicationDataSource.name {
            attributes[ResourceAttributes.serviceName.rawValue] = AttributeValue.string(bundleName)
        }

        if let version = applicationVersion() {
            attributes[ResourceAttributes.serviceVersion.rawValue] = AttributeValue.string(version)
        }

        if let bundleId = applicationDataSource.identifier {
            attributes[ResourceAttributes.serviceNamespace.rawValue] = AttributeValue.string(bundleId)
        }

        return attributes
    }

    func applicationVersion() -> String? {
        if let build = applicationDataSource.build {
            if let version = applicationDataSource.version {
                return "\(version) (\(build))"
            }
            return build
        } else {
            return applicationDataSource.version
        }
    }
}
