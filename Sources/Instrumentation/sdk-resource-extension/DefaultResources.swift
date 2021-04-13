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
import OpenTelemetrySdk

public class DefaultResources {
    // add new resource providers here
    let application = ApplicationResourceProvider(source: ApplicationDataSource())
    let device = DeviceResourceProvider(source: DeviceDataSource())
    let os = OSResourceProvider(source: OperatingSystemDataSource())

    let telemetry = TelemetryResourceProvider(source: TelemetryDataSource())

    public init() {} 
    
    public func get() -> Resource {
        var resource = Resource()
        let mirror = Mirror(reflecting: self)
        for children in mirror.children {
            if let provider = children.value as? ResourceProvider {
                resource.merge(other: provider.create())
            }
        }
        return resource
    }
}
