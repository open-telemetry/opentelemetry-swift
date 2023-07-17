/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest
import OpenTelemetryTestUtils

class ServiceContextManagerTests: ContextManagerTestCase {
    static let provider = OpenTelemetryContextProvider(contextManager: ServiceContextManager())
    override class var contextManager: ContextManager { self.provider.contextManager }

    let key1 = EntryKey(name: "key 1")!
    let value1 = EntryValue(string: "value 1")!
    let key2 = EntryKey(name: "key 2")!
    let value2 = EntryValue(string: "value 2")!

    let metadataTest = EntryMetadata(metadata: "test")

    let defaultTracer = DefaultTracer.instance
    let baggageManager = DefaultBaggageManager.instance
    let firstBytes: [UInt8] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(ascii: "a")]

    var spanContext: SpanContext!

    override func setUp() {
        spanContext = SpanContext.create(traceId: TraceId(fromBytes: firstBytes), spanId: SpanId(fromBytes: firstBytes, withOffset: 8), traceFlags: TraceFlags(), traceState: TraceState())
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
    }

    override func tearDown() {
        XCTAssert(OpenTelemetry.instance.contextProvider.activeSpan === nil)
    }

    func testStateSpan() {
        let expect = expectation(description: "testStateSpan")
        defaultTracer.spanBuilder(spanName: "testStateSpan").withStartedActive { parent in
            let state = Self.provider.getCurrentState()
            DispatchQueue.global().async {
                XCTAssertNil(Self.provider.activeSpan)
                XCTAssertNil(Self.provider.activeBaggage)
                state.withRestoredState {
                    XCTAssertIdentical(parent, Self.provider.activeSpan)
                    self.defaultTracer.spanBuilder(spanName: "testStateSpanChild").withStartedActive { child in
                        XCTAssertIdentical(child, Self.provider.activeSpan)
                    }
                    XCTAssertIdentical(parent, Self.provider.activeSpan)
                }
                XCTAssertNil(Self.provider.activeSpan)
                XCTAssertNil(Self.provider.activeBaggage)
                expect.fulfill()
            }
        }

        self.wait(for: [expect], timeout: 30)
    }

    func testStateBaggage() {
        let expect = expectation(description: "testStateBaggage")
        baggageManager.baggageBuilder().put(key: key1, value: value1, metadata: metadataTest).withActive { baggage in
            let state = Self.provider.getCurrentState()
            DispatchQueue.global().async {
                XCTAssertNil(Self.provider.activeSpan)
                XCTAssertNil(Self.provider.activeBaggage)
                state.withRestoredState {
                    XCTAssertIdentical(baggage, Self.provider.activeBaggage)
                    self.baggageManager.baggageBuilder().put(key: self.key2, value: self.value2, metadata: self.metadataTest).withActive { child in
                        XCTAssertIdentical(child, Self.provider.activeBaggage)
                    }
                    XCTAssertIdentical(baggage, Self.provider.activeBaggage)
                }
                XCTAssertNil(Self.provider.activeSpan)
                XCTAssertNil(Self.provider.activeBaggage)
                expect.fulfill()
            }
        }

        self.wait(for: [expect], timeout: 30)
    }

    func testStateBoth() {
        let expect = expectation(description: "testStateBoth")
        defaultTracer.spanBuilder(spanName: "testStateBoth").withStartedActive { parent in
            self.baggageManager.baggageBuilder().put(key: self.key1, value: self.value1, metadata: self.metadataTest).withActive { baggage in
                let state = Self.provider.getCurrentState()
                DispatchQueue.global().async {
                    XCTAssertNil(Self.provider.activeSpan)
                    XCTAssertNil(Self.provider.activeBaggage)
                    state.withRestoredState {
                        XCTAssertIdentical(baggage, Self.provider.activeBaggage)
                        XCTAssertIdentical(parent, Self.provider.activeSpan)
                        self.baggageManager.baggageBuilder().put(key: self.key2, value: self.value2, metadata: self.metadataTest).withActive { childBaggage in
                            self.defaultTracer.spanBuilder(spanName: "testStateBothChild").withStartedActive { child in
                                XCTAssertIdentical(childBaggage, Self.provider.activeBaggage)
                                XCTAssertIdentical(child, Self.provider.activeSpan)
                            }
                        }
                        XCTAssertIdentical(baggage, Self.provider.activeBaggage)
                        XCTAssertIdentical(parent, Self.provider.activeSpan)
                    }
                    XCTAssertNil(Self.provider.activeSpan)
                    XCTAssertNil(Self.provider.activeBaggage)
                    expect.fulfill()
                }
            }
        }

        self.wait(for: [expect], timeout: 30)
    }
}
