/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest
import OpenTelemetryTestUtils

class SpanBuilderSdkTestInfo: OpenTelemetryContextTestCase {
  let spanName = "span_name"
  let sampledSpanContext = SpanContext.create(traceId: TraceId(idHi: 1000, idLo: 1000),
                                              spanId: SpanId(id: 3000),
                                              traceFlags: TraceFlags().settingIsSampled(true),
                                              traceState: TraceState())
  var tracerSdkFactory = TracerProviderSdk()
  var tracerSdk: Tracer!

  override func setUp() {
    super.setUp()
    tracerSdk = tracerSdkFactory.get(instrumentationName: "SpanBuilderSdkTest")
  }
}

class SpanBuilderSdkTest: SpanBuilderSdkTestInfo {
  func testAddLink() {
    // Verify methods do not crash.
    let spanBuilder = tracerSdk.spanBuilder(spanName: spanName) as! SpanBuilderSdk
    spanBuilder.addLink(SpanData.Link(context: PropagatedSpan().context))
    spanBuilder.addLink(spanContext: PropagatedSpan().context)
    spanBuilder.addLink(spanContext: PropagatedSpan().context, attributes: [String: AttributeValue]())
    let span = spanBuilder.startSpan() as! SpanSdk
    XCTAssertEqual(span.toSpanData().links.count, 3)
    span.end()
  }

  func testTruncateLink() {
    let maxNumberOfLinks = 8
    let spanLimits = tracerSdkFactory.getActiveSpanLimits().settingLinkCountLimit(UInt(maxNumberOfLinks))
    tracerSdkFactory.updateActiveSpanLimits(spanLimits)
    // Verify methods do not crash.
    let spanBuilder = tracerSdk.spanBuilder(spanName: spanName)
    for _ in 0 ..< 2 * maxNumberOfLinks {
      spanBuilder.addLink(spanContext: sampledSpanContext)
    }
    let span = spanBuilder.startSpan() as! SpanSdk
    let spanData = span.toSpanData()
    let links = spanData.links
    XCTAssertEqual(links.count, maxNumberOfLinks)
    for i in 0 ..< maxNumberOfLinks {
      XCTAssert(span.links[i] == SpanData.Link(context: sampledSpanContext))
      XCTAssertEqual(spanData.totalRecordedLinks, 2 * maxNumberOfLinks)
    }
    span.end()
    tracerSdkFactory.updateActiveSpanLimits(SpanLimits())
  }

  func testSetAttribute() {
    let spanBuilder = tracerSdk.spanBuilder(spanName: spanName)
    spanBuilder.setAttribute(key: "string", value: "value")
    spanBuilder.setAttribute(key: "long", value: 12345)
    spanBuilder.setAttribute(key: "double", value: 0.12345)
    spanBuilder.setAttribute(key: "boolean", value: true)
    spanBuilder.setAttribute(key: "stringAttribute", value: AttributeValue.string("attrvalue"))

    let span = spanBuilder.startSpan() as! SpanSdk
    let attrs = span.toSpanData().attributes
    XCTAssertEqual(attrs.count, 5)
    XCTAssertEqual(attrs["string"], AttributeValue.string("value"))
    XCTAssertEqual(attrs["long"], AttributeValue.int(12345))
    XCTAssertEqual(attrs["double"], AttributeValue.double(0.12345))
    XCTAssertEqual(attrs["boolean"], AttributeValue.bool(true))
    XCTAssertEqual(attrs["stringAttribute"], AttributeValue.string("attrvalue"))
    span.end()
  }

  func testSetAttribute_emptyArrayAttributeValue() {
    let spanBuilder = tracerSdk.spanBuilder(spanName: spanName)
    spanBuilder.setAttribute(key: "stringArrayAttribute", value: AttributeValue.array(AttributeArray.empty))
    spanBuilder.setAttribute(key: "boolArrayAttribute", value: AttributeValue.array(AttributeArray.empty))
    spanBuilder.setAttribute(key: "longArrayAttribute", value: AttributeValue.array(AttributeArray.empty))
    spanBuilder.setAttribute(key: "doubleArrayAttribute", value: AttributeValue.array(AttributeArray.empty))
    let span = spanBuilder.startSpan() as! SpanSdk
    XCTAssertEqual(span.toSpanData().attributes.count, 4)
  }

  func testDroppingAttributes() {
    let maxNumberOfAttrs = 8
    let spanLimits = tracerSdkFactory.getActiveSpanLimits().settingAttributeCountLimit(UInt(maxNumberOfAttrs))
    tracerSdkFactory.updateActiveSpanLimits(spanLimits)
    let spanBuilder = tracerSdk.spanBuilder(spanName: spanName)
    for i in 0 ..< 2 * maxNumberOfAttrs {
      spanBuilder.setAttribute(key: "key\(i)", value: i)
    }
    let span = spanBuilder.startSpan() as! SpanSdk
    let attrs = span.toSpanData().attributes
    XCTAssertEqual(attrs.count, maxNumberOfAttrs)
    for i in 0 ..< maxNumberOfAttrs {
      XCTAssertEqual(attrs["key\(i + maxNumberOfAttrs)"], AttributeValue.int(i + maxNumberOfAttrs))
    }
    span.end()
    tracerSdkFactory.updateActiveSpanLimits(SpanLimits())
  }

  func testRecordEvents_default() {
    let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! SpanSdk
    XCTAssertTrue(span.isRecording)
    span.end()
  }

  func testKind_default() {
    let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! SpanSdk
    XCTAssertEqual(span.kind, SpanKind.internal)
    span.end()
  }

  func testKind() {
    let span = tracerSdk.spanBuilder(spanName: spanName).setSpanKind(spanKind: .consumer).startSpan() as! SpanSdk
    XCTAssertEqual(span.kind, SpanKind.consumer)
  }

  func testSampler() {
    let span = TestUtils.createSpanWithSampler(tracerSdkFactory: tracerSdkFactory,
                                               tracer: tracerSdk, spanName: spanName,
                                               sampler: Samplers.alwaysOff)
      .startSpan()

    XCTAssertFalse(span.context.traceFlags.sampled)
    span.end()
  }

  static let samplerAttributeName = "sampler-attribute"

  func testSampler_decisionAttributes() {
    class TestSampler: Sampler {
      var decision: Decision
      func shouldSample(parentContext: SpanContext?,
                        traceId: TraceId,
                        name: String,
                        kind: SpanKind,
                        attributes: [String: AttributeValue],
                        parentLinks: [SpanData.Link]) -> Decision {
        return decision
      }

      var description: String { return "TestSampler" }
      init(decision: Decision) { self.decision = decision }
    }

    class TestDecision: Decision {
      var isSampled: Bool {
        return true
      }

      var attributes: [String: AttributeValue] {
        return [SpanBuilderSdkTest.samplerAttributeName: AttributeValue.string("bar")]
      }
    }

    let decision = TestDecision()
    let sampler = TestSampler(decision: decision)
    let span = TestUtils.createSpanWithSampler(tracerSdkFactory: tracerSdkFactory,
                                               tracer: tracerSdk,
                                               spanName: spanName,
                                               sampler: sampler,
                                               attributes: [SpanBuilderSdkTest.samplerAttributeName: AttributeValue.string("none")])
      .startSpan() as! SpanSdk
    XCTAssertTrue(span.context.traceFlags.sampled)
    XCTAssertTrue(span.toSpanData().attributes.keys.contains(SpanBuilderSdkTest.samplerAttributeName))
    span.end()
  }

  func testSampledViaParentLinks() {
    let span = TestUtils.createSpanWithSampler(tracerSdkFactory: tracerSdkFactory,
                                               tracer: tracerSdk, spanName: spanName,
                                               sampler: Samplers.traceIdRatio(ratio: 0.0))
      .addLink(spanContext: sampledSpanContext)
      .startSpan()
    XCTAssertTrue(span.context.traceFlags.sampled)
    span.end()
  }

  func testNoParent() {
    let parent = tracerSdk.spanBuilder(spanName: spanName).setActive(true).startSpan()
    let span = tracerSdk.spanBuilder(spanName: spanName).setNoParent().startSpan()
    XCTAssertNotEqual(span.context.traceId, parent.context.traceId)
    let spanNoParent = tracerSdk.spanBuilder(spanName: spanName).setNoParent().setParent(parent).setNoParent().startSpan()
    XCTAssertNotEqual(span.context.traceId, parent.context.traceId)
    spanNoParent.end()
    span.end()
    parent.end()
  }

  func testNoParent_override() {
    let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
    let span = tracerSdk.spanBuilder(spanName: spanName).setNoParent().setParent(parent).startSpan() as! SpanSdk
    XCTAssertEqual(span.context.traceId, parent.context.traceId)
    XCTAssertEqual(span.parentContext?.spanId, parent.context.spanId)
    let span2 = tracerSdk.spanBuilder(spanName: spanName).setNoParent().setParent(parent.context).startSpan()
    XCTAssertEqual(span2.context.traceId, parent.context.traceId)
    span2.end()
    span.end()
    parent.end()
  }

  func testOverrideNoParent_remoteParent() {
    let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
    let span = tracerSdk.spanBuilder(spanName: spanName).setNoParent().setParent(parent.context).startSpan() as! SpanSdk
    XCTAssertEqual(span.context.traceId, parent.context.traceId)
    XCTAssertEqual(span.parentContext?.spanId, parent.context.spanId)
    span.end()
    parent.end()
  }

  func testParentCurrentSpan() {
    tracerSdk.spanBuilder(spanName: spanName).setActive(true).withActiveSpan { parent in
      let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! SpanSdk
      XCTAssertEqual(span.context.traceId, parent.context.traceId)
      XCTAssertEqual(span.parentContext?.spanId, parent.context.spanId)
      span.end()
    }
  }

  func testParent_invalidContext() {
    let parent = PropagatedSpan()
    let span = tracerSdk.spanBuilder(spanName: spanName).setParent(parent.context).startSpan() as! SpanSdk
    XCTAssertNotEqual(span.context.traceId, parent.context.traceId)
    XCTAssertNil(span.parentContext?.spanId)
    span.end()
  }

  func testParentEnvironmentContext() {
    setenv("TRACEPARENT", "00-ff000000000000000000000000000041-ff00000000000041-01", 1)
    let providerWithEnv = TracerProviderSdk()
    let tracerAux = providerWithEnv.get(instrumentationName: "SpanBuilderWithEnvTest")
    let parent = tracerAux.spanBuilder(spanName: spanName).setNoParent().setActive(true).startSpan()
    let span = tracerAux.spanBuilder(spanName: spanName).setParent(parent).startSpan()
    XCTAssertEqual(span.context.traceId, parent.context.traceId)
    XCTAssertEqual(parent.context.traceId.hexString, "ff000000000000000000000000000041")
    span.end()
    parent.end()
    unsetenv("TRACEPARENT")
  }

  func testParent_timestampConverter() {
    let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
    let span = tracerSdk.spanBuilder(spanName: spanName).setParent(parent).startSpan() as! SpanSdk
    XCTAssert(span.clock === (parent as! SpanSdk).clock)
    parent.end()
  }

  func testParentCurrentSpan_timestampConverter() {
    tracerSdk.spanBuilder(spanName: spanName).withActiveSpan { parent in
      let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! SpanSdk
      XCTAssert(span.clock === (parent as! SpanSdk).clock)
    }
  }

  func testSpanRestorationInContext() {
    XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
    OpenTelemetry.instance.contextProvider.withActiveSpan(parent) {
      XCTAssertEqual(parent.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
      let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! SpanSdk
      OpenTelemetry.instance.contextProvider.withActiveSpan(span) {
        XCTAssertEqual(span.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
      }
      span.end()
      XCTAssertEqual(parent.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
    }
    parent.end()
    XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
  }
}

final class SpanBuilderSdkTestImperative: SpanBuilderSdkTestInfo {
  override var contextManagers: [any ContextManager] {
    Self.imperativeContextManagers()
  }

  func testParentCurrentSpan() {
    let parent = tracerSdk.spanBuilder(spanName: spanName).setActive(true).startSpan()
    let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! SpanSdk
    XCTAssertEqual(span.context.traceId, parent.context.traceId)
    XCTAssertEqual(span.parentContext?.spanId, parent.context.spanId)
    span.end()
    parent.end()
  }

  func testParentCurrentSpan_timestampConverter() {
    let parent = tracerSdk.spanBuilder(spanName: spanName).setActive(true).startSpan()
    let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! SpanSdk
    XCTAssert(span.clock === (parent as! SpanSdk).clock)
    parent.end()
  }

  func testSpanRestorationInContext() {
    XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
    OpenTelemetry.instance.contextProvider.setActiveSpan(parent)
    XCTAssertEqual(parent.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
    let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! SpanSdk
    OpenTelemetry.instance.contextProvider.setActiveSpan(span)
    XCTAssertEqual(span.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
    span.end()
    XCTAssertEqual(parent.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
    parent.end()
    XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
  }
}

#if canImport(os.activity)
  @preconcurrency import os.activity

  // Bridging Obj-C variabled defined as c-macroses. See `activity.h` header.
  private nonisolated(unsafe) let OS_ACTIVITY_CURRENT = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_os_activity_current"),
                                                  to: os_activity_t.self)
  @_silgen_name("_os_activity_create") private func _os_activity_create(_ dso: UnsafeRawPointer?,
                                                                        _ description: UnsafePointer<Int8>,
                                                                        _ parent: Unmanaged<AnyObject>?,
                                                                        _ flags: os_activity_flag_t) -> AnyObject!

  private nonisolated(unsafe) let dso = UnsafeMutableRawPointer(mutating: #dsohandle)

  final class SpanBuilderSdkTestActivity: SpanBuilderSdkTestInfo {
    override var contextManagers: [any ContextManager] {
      Self.activityContextManagers()
    }

    func testSpanRestorationInContextWithExtraActivities() {
      var activity1State = os_activity_scope_state_s()
      let activity1 = _os_activity_create(dso, "Activity-1", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
      os_activity_scope_enter(activity1, &activity1State)

      XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
      let parent = tracerSdk.spanBuilder(spanName: spanName).setActive(true).startSpan()

      var activity2State = os_activity_scope_state_s()
      let activity2 = _os_activity_create(dso, "Activity-2", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
      os_activity_scope_enter(activity2, &activity2State)

      XCTAssertEqual(parent.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
      let span = tracerSdk.spanBuilder(spanName: spanName).setActive(true).startSpan() as! SpanSdk

      var activity3State = os_activity_scope_state_s()
      let activity3 = _os_activity_create(dso, "Activity-3", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
      os_activity_scope_enter(activity3, &activity3State)

      XCTAssertEqual(span.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
      os_activity_scope_leave(&activity3State)
      span.end()
      os_activity_scope_leave(&activity2State)
      XCTAssertEqual(parent.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
      parent.end()
      os_activity_scope_leave(&activity1State)
      XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    }

    func testSpanRestorationInContextWithExtraActivitiesBlocks() {
      let activity1 = _os_activity_create(dso, "Activity-1", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
      os_activity_apply(activity1) {
        XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
        let parent = tracerSdk.spanBuilder(spanName: spanName).startSpan()
        OpenTelemetry.instance.contextProvider.setActiveSpan(parent)

        let activity2 = _os_activity_create(dso, "Activity-2", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
        os_activity_apply(activity2) {
          XCTAssertEqual(parent.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
          let span = tracerSdk.spanBuilder(spanName: spanName).startSpan() as! SpanSdk
          OpenTelemetry.instance.contextProvider.setActiveSpan(span)

          let activity3 = _os_activity_create(dso, "Activity-3", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
          os_activity_apply(activity3) {
            XCTAssertEqual(span.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
          }
          span.end()
        }
        XCTAssertEqual(parent.context, OpenTelemetry.instance.contextProvider.activeSpan?.context)
        parent.end()
      }
      XCTAssertNil(OpenTelemetry.instance.contextProvider.activeSpan)
    }
  }
#endif
