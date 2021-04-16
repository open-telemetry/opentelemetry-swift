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

public protocol BinaryFormattable {
    /// Deserializes span context from the bytes array.
    /// - Parameter bytes: Bytes array with the envoded span context in it.
    func fromByteArray(bytes: [UInt8]) -> SpanContext?

    /// Serialize span context into an array of bytes.
    /// - Parameter spanContext: Span context to serialize.
    func toByteArray(spanContext: SpanContext) -> [UInt8]
}
