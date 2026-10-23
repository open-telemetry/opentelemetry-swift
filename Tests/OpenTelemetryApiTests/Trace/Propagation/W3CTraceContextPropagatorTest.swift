/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
import XCTest

class W3CTraceContextPropagatorTest: XCTestCase {
  let traceState_default = TraceState()
  let traceState_not_default = TraceState().setting(key: "foo", value: "bar").setting(key: "bar", value: "baz")
  let traceId_base16 = "ff000000000000000000000000000041"
  var traceId: TraceId!
  let spanId_base16 = "ff00000000000041"
  var spanId: SpanId!
  let sampledTraceOptions_bytes: UInt8 = 1
  var sampledTraceOptions: TraceFlags!
  var traceParentHeaderSampled: String!
  var traceParentHeaderNotSampled: String!

  let traceStateNotDefaultEncoding = "foo=bar,bar=baz"
  let httpTraceContext = W3CTraceContextPropagator()

  let setter = TestSetter()
  let getter = TestGetter()

  override func setUp() {
    traceId = TraceId(fromHexString: traceId_base16)
    spanId = SpanId(fromHexString: spanId_base16)
    sampledTraceOptions = TraceFlags(fromByte: sampledTraceOptions_bytes)
    traceParentHeaderSampled = "00-" + traceId_base16 + "-" + spanId_base16 + "-01"
    traceParentHeaderNotSampled = "00-" + traceId_base16 + "-" + spanId_base16 + "-00"
  }

  func testInject_Nothing() {
    var carrier = [String: String]()
    let invalidContext = SpanContext.create(traceId: TraceId(),
                                            spanId: SpanId(),
                                            traceFlags: TraceFlags(),
                                            traceState: TraceState())
    httpTraceContext.inject(spanContext: invalidContext, carrier: &carrier, setter: setter)
    XCTAssertEqual(carrier.count, 0)
  }

  func testInject_SampledContext() {
    var carrier = [String: String]()
    httpTraceContext.inject(spanContext: SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: sampledTraceOptions, traceState: traceState_default), carrier: &carrier, setter: setter)
    XCTAssertEqual(carrier[W3CTraceContextPropagator.traceparent], traceParentHeaderSampled)
  }

  func testInject_NotSampledContext() {
    var carrier = [String: String]()
    httpTraceContext.inject(spanContext: SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState_default), carrier: &carrier, setter: setter)
    XCTAssertEqual(carrier[W3CTraceContextPropagator.traceparent], traceParentHeaderNotSampled)
  }

  func testInject_SampledContext_WithTraceState() {
    var carrier = [String: String]()
    httpTraceContext.inject(spanContext: SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: sampledTraceOptions, traceState: traceState_not_default), carrier: &carrier, setter: setter)
    XCTAssertEqual(carrier[W3CTraceContextPropagator.traceparent], traceParentHeaderSampled)
    XCTAssertEqual(carrier[W3CTraceContextPropagator.traceState], traceStateNotDefaultEncoding)
  }

  func testInject_NotSampledContext_WithTraceState() {
    var carrier = [String: String]()
    httpTraceContext.inject(spanContext: SpanContext.create(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState_not_default), carrier: &carrier, setter: setter)
    XCTAssertEqual(carrier[W3CTraceContextPropagator.traceparent], traceParentHeaderNotSampled)
    XCTAssertEqual(carrier[W3CTraceContextPropagator.traceState], traceStateNotDefaultEncoding)
  }

  func testInject_RandomContext() {
    var carrier = [String: String]()
    let randomTraceOptions = TraceFlags().settingIsRandom(true)
    httpTraceContext.inject(
      spanContext: SpanContext.create(
        traceId: traceId,
        spanId: spanId,
        traceFlags: randomTraceOptions,
        traceState: traceState_default
      ),
      carrier: &carrier,
      setter: setter
    )
    XCTAssertEqual(
      carrier[W3CTraceContextPropagator.traceparent],
      "00-" + traceId_base16 + "-" + spanId_base16 + "-02"
    )
  }

  func testExtract_SampledContext() {
    var carrier = [String: String]()
    carrier[W3CTraceContextPropagator.traceparent] = traceParentHeaderSampled
    XCTAssertEqual(httpTraceContext.extract(carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: sampledTraceOptions, traceState: traceState_not_default))
  }

  func testExtract_NotSampledContext() {
    var carrier = [String: String]()
    carrier[W3CTraceContextPropagator.traceparent] = traceParentHeaderNotSampled
    XCTAssertEqual(httpTraceContext.extract(carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState_default))
  }

  func testExtract_SampledContext_WithTraceState() {
    var carrier = [String: String]()
    carrier[W3CTraceContextPropagator.traceparent] = traceParentHeaderSampled
    carrier[W3CTraceContextPropagator.traceState] = traceStateNotDefaultEncoding
    XCTAssertEqual(httpTraceContext.extract(carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: sampledTraceOptions, traceState: traceState_not_default))
  }

  func testExtract_NotSampledContext_WithTraceState() {
    var carrier = [String: String]()
    carrier[W3CTraceContextPropagator.traceparent] = traceParentHeaderNotSampled
    carrier[W3CTraceContextPropagator.traceState] = traceStateNotDefaultEncoding
    XCTAssertEqual(httpTraceContext.extract(carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState_not_default))
  }

  func testExtract_RandomContext() {
    var carrier = [String: String]()
    carrier[W3CTraceContextPropagator.traceparent] = "00-" + traceId_base16 + "-" + spanId_base16 + "-02"
    XCTAssertEqual(
      httpTraceContext.extract(carrier: carrier, getter: getter),
      SpanContext.createFromRemoteParent(
        traceId: traceId,
        spanId: spanId,
        traceFlags: TraceFlags().settingIsRandom(true),
        traceState: traceState_default
      )
    )
  }

  func testExtract_NotSampledContext_NextVersion() {
    var carrier = [String: String]()
    carrier[W3CTraceContextPropagator.traceparent] = "01-" + traceId_base16 + "-" + spanId_base16 + "-00-02"
    XCTAssertEqual(httpTraceContext.extract(carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState_default))
  }

  func testExtract_NotSampledContext_EmptyTraceState() {
    var carrier = [String: String]()
    carrier[W3CTraceContextPropagator.traceparent] = traceParentHeaderNotSampled
    carrier[W3CTraceContextPropagator.traceState] = ""
    XCTAssertEqual(httpTraceContext.extract(carrier: carrier, getter: getter), SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState_default))
  }

  func testExtract_NotSampledContext_TraceStateWithSpaces() throws {
    var carrier = [String: String]()
    carrier[W3CTraceContextPropagator.traceparent] = traceParentHeaderNotSampled
    carrier[W3CTraceContextPropagator.traceState] = "foo=bar   ,    bar=baz"
    let context = try XCTUnwrap(httpTraceContext.extract(carrier: carrier, getter: getter))
    XCTAssertEqual(context, SpanContext.createFromRemoteParent(traceId: traceId, spanId: spanId, traceFlags: TraceFlags(), traceState: traceState_not_default))
    XCTAssertEqual(context.traceState.entries, traceState_not_default.entries)
  }

  func testExtract_InvalidTraceId() {
    var invalidHeaders = [String: String]()
    invalidHeaders[W3CTraceContextPropagator.traceparent] = "00-" + "abcdefghijklmnopabcdefghijklmnop" + "-" + spanId_base16 + "-01"
    XCTAssertNil(httpTraceContext.extract(carrier: invalidHeaders, getter: getter))
  }

  func testExtract_InvalidTraceId_Size() {
    var invalidHeaders = [String: String]()
    invalidHeaders[W3CTraceContextPropagator.traceparent] = "00-" + traceId_base16 + "00-" + spanId_base16 + "-01"
    XCTAssertNil(httpTraceContext.extract(carrier: invalidHeaders, getter: getter))
  }

  func testExtract_InvalidSpanId() {
    var invalidHeaders = [String: String]()
    invalidHeaders[W3CTraceContextPropagator.traceparent] = "00-" + traceId_base16 + "-" + "abcdefghijklmnop" + "-01"
    XCTAssertNil(httpTraceContext.extract(carrier: invalidHeaders, getter: getter))
  }

  func testExtract_InvalidSpanId_Size() {
    var invalidHeaders = [String: String]()
    invalidHeaders[W3CTraceContextPropagator.traceparent] = "00-" + traceId_base16 + "-" + spanId_base16 + "00-01"
    XCTAssertNil(httpTraceContext.extract(carrier: invalidHeaders, getter: getter))
  }

  func testExtract_InvalidTraceFlags() {
    var invalidHeaders = [String: String]()
    invalidHeaders[W3CTraceContextPropagator.traceparent] = "00-" + traceId_base16 + "-" + spanId_base16 + "-gh"
    XCTAssertNil(httpTraceContext.extract(carrier: invalidHeaders, getter: getter))
  }

  func testExtract_InvalidTraceFlags_Size() {
    var invalidHeaders = [String: String]()
    invalidHeaders[W3CTraceContextPropagator.traceparent] = "00-" + traceId_base16 + "-" + spanId_base16 + "-0100"
    XCTAssertNil(httpTraceContext.extract(carrier: invalidHeaders, getter: getter))
  }

//    func testExtract_InvalidTraceState_EntriesDelimiter() {
//        var invalidHeaders = [String: String]()
//        invalidHeaders[W3CTraceContextPropagator.traceparent] = "00-" + traceId_base16 + "-" + spanId_base16 + "-01"
//        invalidHeaders[W3CTraceContextPropagator.traceState] = "foo=bar;test=test"
//        XCTAssertNil(httpTraceContext.extract(carrier: invalidHeaders, getter: getter))
//    }//
//    func testExtract_InvalidTraceState_KeyValueDelimiter() {
//        var invalidHeaders = [String: String]()
//        invalidHeaders[W3CTraceContextPropagator.traceparent] = "00-" + traceId_base16 + "-" + spanId_base16 + "-01"
//        invalidHeaders[W3CTraceContextPropagator.traceState] = "foo=bar,test-test"
//        XCTAssertNil(httpTraceContext.extract(carrier: invalidHeaders, getter: getter))
//    }//
//    func testExtract_InvalidTraceState_OneString() {
//        var invalidHeaders = [String: String]()
//        invalidHeaders[W3CTraceContextPropagator.traceparent] = "00-" + traceId_base16 + "-" + spanId_base16 + "-01"
//        invalidHeaders[W3CTraceContextPropagator.traceState] = "test-test"
//        XCTAssertNil(httpTraceContext.extract(carrier: invalidHeaders, getter: getter))
//    }

  func testExtract_InvalidVersionCharacters() {
    for version in ["zz", "g0", "0g", " 0", "0 ", "é0", "0é"] {
      let carrier = [W3CTraceContextPropagator.traceparent: version + "-" + traceId_base16 + "-" + spanId_base16 + "-01"]
      XCTAssertNil(httpTraceContext.extract(carrier: carrier, getter: getter), "Version: \(version)")
    }
  }

  func testExtract_ReservedVersion() {
    let carrier = [W3CTraceContextPropagator.traceparent: "ff-" + traceId_base16 + "-" + spanId_base16 + "-01"]
    XCTAssertNil(httpTraceContext.extract(carrier: carrier, getter: getter))
  }

  func testExtract_TraceStateRoundTrip() throws {
    let carrier = try [W3CTraceContextPropagator.traceparent: XCTUnwrap(traceParentHeaderSampled),
                       W3CTraceContextPropagator.traceState: traceStateNotDefaultEncoding]
    let context = try XCTUnwrap(httpTraceContext.extract(carrier: carrier, getter: getter))
    // SpanContext equality does not compare tracestate, so inspect it explicitly.
    XCTAssertEqual(context.traceState.entries, traceState_not_default.entries)
    var output = [String: String]()
    httpTraceContext.inject(spanContext: context, carrier: &output, setter: setter)
    XCTAssertEqual(output[W3CTraceContextPropagator.traceState], traceStateNotDefaultEncoding)
  }

  func testExtract_InvalidTraceStatePreservesParent() throws {
    for state in ["", "missing-equals", "foo=bar,foo=baz"] {
      let carrier = try [W3CTraceContextPropagator.traceparent: XCTUnwrap(traceParentHeaderSampled),
                         W3CTraceContextPropagator.traceState: state]
      let context = try XCTUnwrap(httpTraceContext.extract(carrier: carrier, getter: getter))
      XCTAssertEqual(context.traceId, traceId)
      XCTAssertEqual(context.spanId, spanId)
      XCTAssertTrue(context.traceState.entries.isEmpty)
    }
  }

  private struct MultiHeaderGetter: Getter {
    let traceStates: [String]

    func get(carrier: [String: String], key: String) -> [String]? {
      key == W3CTraceContextPropagator.traceState ? traceStates : carrier[key].map { [$0] }
    }
  }

  private func extractWithTraceStates(_ states: [String]) throws -> SpanContext {
    let carrier = try [W3CTraceContextPropagator.traceparent: XCTUnwrap(traceParentHeaderSampled)]
    return try XCTUnwrap(httpTraceContext.extract(carrier: carrier, getter: MultiHeaderGetter(traceStates: states)))
  }

  func testExtract_MultipleTraceStateHeadersPreserveOrder() throws {
    let context = try extractWithTraceStates(["first=1,second=2", "third=3"])
    XCTAssertEqual(context.traceState.entries.map(\.key), ["first", "second", "third"])
    var output = [String: String]()
    httpTraceContext.inject(spanContext: context, carrier: &output, setter: setter)
    XCTAssertEqual(output[W3CTraceContextPropagator.traceState], "first=1,second=2,third=3")
  }

  func testExtract_DuplicateTraceStateKeysAcrossHeadersPreserveParent() throws {
    let context = try extractWithTraceStates(["same=1", "same=2"])
    XCTAssertEqual(context.traceId, traceId)
    XCTAssertEqual(context.spanId, spanId)
    XCTAssertTrue(context.traceState.entries.isEmpty)
  }

  func testExtract_TraceStateOptionalWhitespaceAndEmptyMembers() throws {
    for states in [
      ["foo=bar   ,    bar=baz"],
      ["\tfoo=bar\t,\tbar=baz\t"],
      ["", " \t", "foo=bar", "", "bar=baz", ""],
      [", ,foo=bar,,\t,bar=baz, "]
    ] {
      let context = try extractWithTraceStates(states)
      XCTAssertEqual(context.traceState.entries, traceState_not_default.entries, "Headers: \(states)")
    }
  }

  func testExtract_TraceStateDoesNotTrimWhitespaceInsideMembers() throws {
    for state in ["foo =bar", "foo=ba\tr", "foo=bar\n", "foo=bar\r"] {
      let context = try extractWithTraceStates([state])
      XCTAssertTrue(context.traceState.entries.isEmpty, "Header: \(state)")
      XCTAssertEqual(context.traceId, traceId)
    }
    let context = try extractWithTraceStates(["foo=bar baz"])
    XCTAssertEqual(context.traceState.get(key: "foo"), "bar baz")
  }

  func testExtract_TraceStateLimitAppliesAcrossHeaders() throws {
    let members = (0 ..< 33).map { "k\($0)=v" }
    for states in [
      [members.prefix(32).joined(separator: ",")],
      [members.prefix(16).joined(separator: ","), members.dropFirst(16).prefix(16).joined(separator: ",")],
      [members.joined(separator: ",")],
      [members.prefix(32).joined(separator: ","), members[32]]
    ] {
      let context = try extractWithTraceStates(states)
      XCTAssertEqual(context.traceState.entries.map(\.key), (0 ..< 32).map { "k\($0)" })
    }
  }

  func testFieldsList() {
    XCTAssertTrue(httpTraceContext.fields.contains(W3CTraceContextPropagator.traceparent))
    XCTAssertTrue(httpTraceContext.fields.contains(W3CTraceContextPropagator.traceparent))
    XCTAssertEqual(httpTraceContext.fields.count, 2)
  }

  func testHeaderNames() {
    XCTAssertEqual(W3CTraceContextPropagator.traceparent, "traceparent")
    XCTAssertEqual(W3CTraceContextPropagator.traceState, "tracestate")
  }

  func testExtract_EmptyCarrier() {
    let emptyHeaders = [String: String]()
    XCTAssertNil(httpTraceContext.extract(carrier: emptyHeaders, getter: getter))
  }
}
