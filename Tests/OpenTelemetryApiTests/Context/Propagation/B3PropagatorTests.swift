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

class B3PropagatorTests: XCTestCase {
    
    let traceIdHexString = "ff000000000000000000000000000041"
    var traceId: TraceId!
    let spanIdHexString = "ff00000000000041"
    var spanId: SpanId!
    let traceFlagsBytes: UInt8 = 1
    var traceFlags: TraceFlags!
    let traceState = TraceState()
    private let b3Propagator = B3Propagator()
    private let singleHeaderB3Propagator = B3Propagator(true)
    let setter = TestSetter()
    let getter = TestGetter()
    
    struct TestSetter: Setter {
        func set(carrier: inout [String: String], key: String, value: String) {
            carrier[key] = value
        }
    }

    struct TestGetter: Getter {
        func get(carrier: [String: String], key: String) -> [String]? {
            if let value = carrier[key] {
                return [value]
            }
            return nil
        }
    }
    
    override func setUp() {
        traceId = TraceId(fromHexString: traceIdHexString)
        spanId = SpanId(fromHexString: spanIdHexString)
        traceFlags = TraceFlags(fromByte: traceFlagsBytes)
    }
    
    func getSpanContext() -> SpanContext? {
        return ContextUtils.getCurrentSpan()?.context
    }
    
    func testInject_SampledContext() {
        var carrier = [String: String]()
        b3Propagator.inject(spanContext: SpanContext.create(traceId: traceId , spanId: spanId, traceFlags: traceFlags, traceState: traceState), carrier: &carrier, setter: setter)
        XCTAssertEqual(carrier[B3Propagator.traceIdHeader], traceIdHexString)
        XCTAssertEqual(carrier[B3Propagator.spanIdHeader], spanIdHexString)
        XCTAssertEqual(carrier[B3Propagator.sampledHeader], B3Propagator.trueInt)
    }
    
    func testInject_NotSampledContext() {
        var carrier = [String: String]()
        b3Propagator.inject(spanContext: SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState), carrier: &carrier, setter: setter)
        XCTAssertEqual(carrier[B3Propagator.traceIdHeader], traceIdHexString)
        XCTAssertEqual(carrier[B3Propagator.spanIdHeader], spanIdHexString)
        XCTAssertEqual(carrier[B3Propagator.sampledHeader], B3Propagator.falseInt)
    }
    
    func testExtract_SampledContext_Int() {
        var carrier = [String: String]()
        carrier[B3Propagator.traceIdHeader] = traceIdHexString
        carrier[B3Propagator.spanIdHeader] = spanIdHexString
        carrier[B3Propagator.sampledHeader] = B3Propagator.trueInt
        
        XCTAssertEqual(b3Propagator.extract(spanContext: getSpanContext(), carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: traceFlags, traceState: traceState))
    }
    
    func testExtract_SampledContext_Bool() {
        var carrier = [String: String]()
        carrier[B3Propagator.traceIdHeader] = traceIdHexString
        carrier[B3Propagator.spanIdHeader] = spanIdHexString
        carrier[B3Propagator.sampledHeader] = "true"
        
        XCTAssertEqual(b3Propagator.extract(spanContext: getSpanContext(), carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: traceFlags, traceState: traceState))
    }
    
    func testExtract_NotSampledContext() {
        var carrier = [String: String]()
        carrier[B3Propagator.traceIdHeader] = traceIdHexString
        carrier[B3Propagator.spanIdHeader] = spanIdHexString
        carrier[B3Propagator.sampledHeader] = B3Propagator.falseInt
        
        XCTAssertEqual(b3Propagator.extract(spanContext: getSpanContext(), carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState))
    }
    
    func testInject_SampledContext_SingleHeader() {
        var carrier = [String: String]()
        singleHeaderB3Propagator.inject(spanContext: SpanContext.create(traceId: traceId , spanId: spanId, traceFlags: traceFlags, traceState: traceState), carrier: &carrier, setter: setter)
        XCTAssertEqual(carrier[B3Propagator.combinedHeader], "\(traceIdHexString)-\(spanIdHexString)-1")
    }
    
    func testInject_NotSampledContext_SingleHeader() {
        var carrier = [String: String]()
        singleHeaderB3Propagator.inject(spanContext: SpanContext.create(traceId: traceId , spanId: spanId, traceFlags: TraceFlags(), traceState: traceState), carrier: &carrier, setter: setter)
        XCTAssertEqual(carrier[B3Propagator.combinedHeader], "\(traceIdHexString)-\(spanIdHexString)-0")
    }
    
    func testExtract_SampledContext_Int_SingleHeader() {
        var carrier = [String: String]()
        carrier[B3Propagator.combinedHeader] = "\(traceIdHexString)-\(spanIdHexString)-\(B3Propagator.trueInt)"
        XCTAssertEqual(singleHeaderB3Propagator.extract(spanContext: getSpanContext(), carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: traceFlags, traceState: traceState))
    }
    
    func testExtract_SampledContext_Int_DebugFlag_SindleHeader() {
        var carrier = [String: String]()
        carrier[B3Propagator.combinedHeader] = "\(traceIdHexString)-\(spanIdHexString)-\(B3Propagator.trueInt)-0"
        XCTAssertEqual(singleHeaderB3Propagator.extract(spanContext: getSpanContext(), carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: traceFlags, traceState: traceState))
    }
    
    func testExtract_SampledContext_Bool_SingleHeader() {
        var carrier = [String: String]()
        carrier[B3Propagator.combinedHeader] = "\(traceIdHexString)-\(spanIdHexString)-true"
        XCTAssertEqual(singleHeaderB3Propagator.extract(spanContext: getSpanContext(), carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: traceFlags, traceState: traceState))
    }
    
    func testExtract_SampledContext_Bool_DebugFlag_SindleHeader() {
        var carrier = [String: String]()
        carrier[B3Propagator.combinedHeader] = "\(traceIdHexString)-\(spanIdHexString)-true-0"
        XCTAssertEqual(singleHeaderB3Propagator.extract(spanContext: getSpanContext(), carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: traceFlags, traceState: traceState))
    }
    
    func testExtract_NotSampledContext_SingleHeader() {
        var carrier = [String: String]()
        carrier[B3Propagator.combinedHeader] = "\(traceIdHexString)-\(spanIdHexString)-\(B3Propagator.falseInt)"
        XCTAssertEqual(singleHeaderB3Propagator.extract(spanContext: getSpanContext(), carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState))
    }
    
    func testExtract_Empty_SindleHeader() {
        var invalidHeaders = [String: String]()
        invalidHeaders[B3Propagator.combinedHeader] = ""
        XCTAssertEqual(singleHeaderB3Propagator.extract(spanContext: getSpanContext(), carrier: invalidHeaders, getter: getter), SpanContext.invalid)
    }
}
