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

/// A link to a Span.
/// Used (for example) in batching operations, where a single batch handler processes multiple
/// requests from different traces. Link can be also used to reference spans from the same trace.
public protocol Link: AnyObject {
    /// The SpanContext
    var context: SpanContext { get }
    /// The set of attribute
    var attributes: [String: AttributeValue] { get }
}

public func == (lhs: Link, rhs: Link) -> Bool {
    return lhs.context == rhs.context && lhs.attributes == rhs.attributes
}

public func == (lhs: [Link], rhs: [Link]) -> Bool {
    return lhs.elementsEqual(rhs) { $0.context == $1.context && $0.attributes == $1.attributes }
}
