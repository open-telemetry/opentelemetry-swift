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

/// No-op implementations of CorrelationContextManager.
public class DefaultCorrelationContextManager: CorrelationContextManager {
    ///  Returns a CorrelationContextManager singleton that is the default implementation for
    ///  CorrelationContextManager.
    static var instance = DefaultCorrelationContextManager()
    static var binaryFormat = BinaryTraceContextFormat()
    static var httpTextFormat = HttpTraceContextFormat()

    private init() {}

    public func contextBuilder() -> CorrelationContextBuilder {
        return EmptyCorrelationContextBuilder()
    }

    public func getCurrentContext() -> CorrelationContext {
        ContextUtils.getCurrentCorrelationContext() ?? EmptyCorrelationContext.instance
    }

    public func withContext(distContext: CorrelationContext) -> Scope {
        return ContextUtils.withCorrelationContext(distContext)
    }

    public func getBinaryFormat() -> BinaryFormattable {
        return DefaultCorrelationContextManager.binaryFormat
    }

    public func getHttpTextFormat() -> TextFormattable {
        return DefaultCorrelationContextManager.httpTextFormat
    }
}
