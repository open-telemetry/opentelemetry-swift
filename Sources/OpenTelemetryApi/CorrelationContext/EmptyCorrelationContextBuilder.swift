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

public class EmptyCorrelationContextBuilder: CorrelationContextBuilder {
    public func setParent(_ parent: CorrelationContext) -> Self {
        return self
    }

    public func setNoParent() -> Self {
        return self
    }

    public func put(key: EntryKey, value: EntryValue, metadata: EntryMetadata) -> Self {
        return self
    }

    public func remove(key: EntryKey) -> Self {
        return self
    }

    public func build() -> CorrelationContext {
        return EmptyCorrelationContext.instance
    }

    public init() {}
}
