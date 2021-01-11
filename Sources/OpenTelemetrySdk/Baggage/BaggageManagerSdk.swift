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
import OpenTelemetryApi

/// BaggageManagerSdk is SDK implementation of BaggageManager.
public class BaggageManagerSdk: BaggageManager {
    public init() {
    }

    public func baggageBuilder() -> BaggageBuilder {
        return BaggageSdkBuilder()
    }

    public func getCurrentContext() -> Baggage {
        return ContextUtils.getCurrentBaggage() ?? EmptyBaggage.instance
    }

    public func withContext(baggage: Baggage) -> Scope {
        return ContextUtils.withBaggage(baggage)
    }
}
