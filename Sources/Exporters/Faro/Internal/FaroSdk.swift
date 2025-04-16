/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon

final class FaroSdk {
  private let appInfo: FaroAppInfo
  private let transport: FaroTransport
  private let sessionManager: FaroSessionManaging
  private let telemetryDataQueue = DispatchQueue(label: "com.opentelemetry.faro.telemetryDataQueue")
  private let flushQueue = DispatchQueue(label: "com.opentelemetry.faro.flush")

  private let flushInterval: TimeInterval = 2.0 // seconds
  private var flushWorkItem: DispatchWorkItem?

  private var pendingLogs: [FaroLog] = []
  private var pendingEvents: [FaroEvent] = []
  private var pendingSpans: [SpanData] = []

  init(appInfo: FaroAppInfo, transport: FaroTransport, sessionManager: FaroSessionManaging) {
    self.appInfo = appInfo
    self.transport = transport
    self.sessionManager = sessionManager

    sendSessionStartEvent()
  }

  func pushEvents(events: [FaroEvent]) {
    telemetryDataQueue.sync {
      pendingEvents.append(contentsOf: events)
    }
    scheduleFlush()
  }

  func pushLogs(_ logs: [FaroLog]) {
    telemetryDataQueue.sync {
      pendingLogs.append(contentsOf: logs)
    }
    scheduleFlush()
  }
  
  func pushSpans(_ spans: [SpanData]) {
    telemetryDataQueue.sync {
      pendingSpans.append(contentsOf: spans)
    }
    scheduleFlush()
  }

  private func sendSessionStartEvent() {
    let sessionStartEvent = FaroEvent.create(name: "session_start")
    pushEvents(events: [sessionStartEvent])
  }

  private func scheduleFlush() {
    if flushWorkItem == nil {
      let workItem = DispatchWorkItem { [weak self] in
        self?.flushPendingData()
      }
      flushWorkItem = workItem
      flushQueue.asyncAfter(deadline: .now() + flushInterval, execute: workItem)
    }
  }

  private func flushPendingData() {
    var sendingLogs: [FaroLog] = []
    var sendingEvents: [FaroEvent] = []
    var sendingSpans: [SpanData] = []

    telemetryDataQueue.sync {
      sendingLogs = pendingLogs
      sendingEvents = pendingEvents
      sendingSpans = pendingSpans
      pendingLogs = []
      pendingEvents = []
      pendingSpans = []

      flushWorkItem?.cancel()
      flushWorkItem = nil
    }

    if !sendingLogs.isEmpty || !sendingEvents.isEmpty || !sendingSpans.isEmpty {
      let payload = getPayload(logs: sendingLogs, events: sendingEvents, spans: sendingSpans)
      transport.send(payload) { [weak self] result in
        switch result {
        case .success:
          // Data sent successfully
          break
        case let .failure(error):
          print("FaroSdk: Failed to send telemetry: \(error)")
          self?.telemetryDataQueue.sync {
            // Simply add failed items back to pending queues
            self?.pendingLogs.append(contentsOf: sendingLogs)
            self?.pendingEvents.append(contentsOf: sendingEvents)
            self?.pendingSpans.append(contentsOf: sendingSpans)
            // No explicit retry scheduling - next natural data addition will trigger it
          }
        }
      }
    }
  }

  private func getPayload(logs: [FaroLog], events: [FaroEvent], spans: [SpanData] = []) -> FaroPayload {
    let traces = spans.isEmpty ? nil : Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.with {
      $0.resourceSpans = SpanAdapter.toProtoResourceSpans(spanDataList: spans)
    }
    
    return FaroPayload(
      meta: FaroMeta(
        sdk: FaroSdkInfo(name: "opentelemetry-swift-faro-exporter", version: "1.3.5", integrations: []), // TODO: check if we can get this from Otel
        app: appInfo,
        session: FaroSession(id: sessionManager.getSessionId(), attributes: [:]), // TODO: check if we can get the device attributes, or map them
        user: nil,
        view: FaroView(name: "default")
      ),
      traces: traces,
      logs: logs,
      events: events
    )
  }
}
