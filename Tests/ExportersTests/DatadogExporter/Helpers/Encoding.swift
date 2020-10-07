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
@testable import DatadogExporter

extension EncodableValue: Equatable {
    public static func == (lhs: EncodableValue, rhs: EncodableValue) -> Bool {
        return String(describing: lhs) == String(describing: rhs)
    }
}

/// Prior to `iOS13.0`, the `JSONEncoder` supports only object or array as the root type.
/// Hence we can't test encoding `Encodable` values directly and we need as support of this `EncodingContainer` container.
///
/// Reference: https://bugs.swift.org/browse/SR-6163
struct EncodingContainer<Value: Encodable>: Encodable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
