/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

final class FaroSdk {
  private let appInfo: FaroAppInfo
  private let transport: FaroTransport
  private let sessionManager: FaroSessionManaging
  private let exporterQueue = DispatchQueue(label: "com.opentelemetry.faro.exporter")
  
  private let flushInterval: TimeInterval = 2.0 // seconds
  private var flushTimer: Timer?

  private var pendingLogs: [FaroLog] = []
  private var pendingEvents: [FaroEvent] = []

  init(appInfo: FaroAppInfo, transport: FaroTransport, sessionManager: FaroSessionManaging) {
    self.appInfo = appInfo
    self.transport = transport
    self.sessionManager = sessionManager
  }

  func pushEvents(events: [FaroEvent]) {
    exporterQueue.sync {
      pendingEvents.append(contentsOf: events)
      scheduleFlush()
    }
  }

  func pushLogs(_ logs: [FaroLog]) {
    exporterQueue.sync {
      pendingLogs.append(contentsOf: logs)
      scheduleFlush()
    }
  }

  private func scheduleFlush() {
    if flushTimer == nil {
      flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: false) { [weak self] _ in
        self?.flushPendingData()
      }
    }
  }

  private func flushPendingData() {
    var sendingLogs: [FaroLog] = []
    var sendingEvents: [FaroEvent] = []
    
    exporterQueue.sync {
      sendingLogs = pendingLogs
      sendingEvents = pendingEvents
      pendingLogs = []
      pendingEvents = []
      
      flushTimer?.invalidate()
      flushTimer = nil
    }
    
    if !sendingLogs.isEmpty || !sendingEvents.isEmpty {
      let payload = getPayload(logs: sendingLogs, events: sendingEvents)
      transport.send(payload) { [weak self] result in
        switch result {
        case .success:
          // Data sent successfully
          break
        case let .failure(error):
          print("Failed to send telemetry: \(error)")
          self?.exporterQueue.sync {
            // Simply add failed items back to pending queues
            self?.pendingLogs.append(contentsOf: sendingLogs)
            self?.pendingEvents.append(contentsOf: sendingEvents)
            // No explicit retry scheduling - next natural data addition will trigger it
          }
        }
      }
    }
  }

  private func getPayload(logs: [FaroLog], events: [FaroEvent]) -> FaroPayload {
    return FaroPayload(
      meta: FaroMeta(
        sdk: FaroSdkInfo(name: "opentelemetry-swift", version: "1.0.0", integrations: []), // TODO: check if we can get this from Otel
        app: appInfo,
        session: FaroSession(id: sessionManager.getSessionId(), attributes: [:]),
        user: nil,
        view: FaroView(name: "default")
      ),
      logs: logs,
      events: events
    )
  }
}
