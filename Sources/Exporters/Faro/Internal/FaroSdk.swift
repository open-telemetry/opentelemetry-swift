/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

final class FaroSdk {
  private var pendingLogs: [FaroLog] = []
  private let appInfo: FaroAppInfo
  private let transport: FaroTransport
  private let exporterLogsQueue = DispatchQueue(label: "com.opentelemetry.faro.logs")

  init(appInfo: FaroAppInfo, transport: FaroTransport) {
    self.appInfo = appInfo
    self.transport = transport
  }

  func addLogs(_ logs: [FaroLog]) {
    var sendingLogs: [FaroLog] = []

    exporterLogsQueue.sync {
      pendingLogs.append(contentsOf: logs)
      sendingLogs = pendingLogs
      pendingLogs = []
    }

    if !sendingLogs.isEmpty {
      let payload = getPayload(with: sendingLogs)
      transport.send(payload) { [weak self] result in
        switch result {
        case .success:
          // Logs sent successfully
          break
        case let .failure(error):
          print("Failed to send logs: \(error)")
          self?.exporterLogsQueue.sync {
            self?.pendingLogs.append(contentsOf: sendingLogs)
          }
        }
      }
    }
  }

  private func getPayload(with logs: [FaroLog]) -> FaroPayload {
    return FaroPayload(
      meta: FaroMeta(
        sdk: FaroSdkInfo(name: "opentelemetry-swift", version: "1.0.0", integrations: []),
        app: appInfo,
        session: FaroSession(id: UUID().uuidString, attributes: [:]),
        user: FaroUser(id: "", username: "", email: "", attributes: [:]),
        view: FaroView(name: "")
      ),
      logs: logs
    )
  }
}
