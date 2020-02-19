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

@testable import OpenTelemetryApi
import XCTest

class SpanBuilderTests: XCTestCase {
    class TestLink: Link {
        var context: SpanContext {
            return DefaultSpan.random().context
        }

        var attributes: [String: AttributeValue] {
            return [String: AttributeValue]()
        }
    }

    let tracer = DefaultTracer.instance

    func testDoNotCrash_NoopImplementation() {
        let spanBuilder = tracer.spanBuilder(spanName: "MySpanName")
        spanBuilder.setSpanKind(spanKind: .server)
        spanBuilder.setParent(DefaultSpan.random())
        spanBuilder.setParent(DefaultSpan.random().context)
        spanBuilder.setNoParent()
        spanBuilder.addLink(spanContext: DefaultSpan.random().context)
        spanBuilder.addLink(spanContext: DefaultSpan.random().context, attributes: [String: AttributeValue]())
        spanBuilder.addLink(spanContext: DefaultSpan.random().context, attributes: [String: AttributeValue]())
        spanBuilder.addLink(TestLink())
        spanBuilder.setAttribute(key: "key", value: "value")
        spanBuilder.setAttribute(key: "key", value: 12345)
        spanBuilder.setAttribute(key: "key", value: 0.12345)
        spanBuilder.setAttribute(key: "key", value: true)
        spanBuilder.setAttribute(key: "key", value: AttributeValue.string("value"))
        spanBuilder.setStartTimestamp(startTimestamp: 12345)
        XCTAssert(spanBuilder.startSpan() is DefaultSpan)
    }
}
