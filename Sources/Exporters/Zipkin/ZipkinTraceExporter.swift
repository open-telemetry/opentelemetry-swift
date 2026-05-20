/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public final class ZipkinTraceExporter: SpanExporter {
  public let options: ZipkinTraceExporterOptions
  let localEndPoint: ZipkinEndpoint

  public init(options: ZipkinTraceExporterOptions) {
    self.options = options
    localEndPoint = ZipkinTraceExporter.getLocalZipkinEndpoint(name: options.serviceName)
  }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    guard let url = URL(string: options.endpoint) else { return .failure }

    var request = URLRequest(url: url)
    request.timeoutInterval = min(explicitTimeout ?? TimeInterval.greatestFiniteMagnitude, options.timeoutSeconds)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    options.additionalHeaders.forEach {
      request.addValue($0.value, forHTTPHeaderField: $0.key)
    }

    let spans = encodeSpans(spans: spans)
    do {
      request.httpBody = try JSONEncoder().encode(spans)
    } catch {
      return .failure
    }

    // The URLSession completion handler is `@Sendable`. Bridge the result
    // through a class-backed locked box so the semaphore.wait() side observes
    // a well-defined value without tripping Swift 6's concurrent-capture
    // checks (which disallow mutating a captured `var` even under a lock).
    final class StatusBox: @unchecked Sendable {
      private let lock = NSLock()
      private var value: SpanExporterResultCode = .failure
      func set(_ v: SpanExporterResultCode) { lock.withLock { value = v } }
      func get() -> SpanExporterResultCode { lock.withLock { value } }
    }
    let statusBox = StatusBox()
    let sem = DispatchSemaphore(value: 0)

    let task = URLSession.shared.dataTask(with: request) { _, _, error in
      statusBox.set(error == nil ? .success : .failure)
      sem.signal()
    }
    task.resume()
    sem.wait()

    return statusBox.get()
  }

  public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
    return .success
  }

  public func shutdown(explicitTimeout: TimeInterval? = nil) {}

  func encodeSpans(spans: [SpanData]) -> [ZipkinSpan] {
    return spans.map { ZipkinConversionExtension.toZipkinSpan(otelSpan: $0, defaultLocalEndpoint: localEndPoint) }
  }

  static func getLocalZipkinEndpoint(name: String? = nil) -> ZipkinEndpoint {
    let hostname = name ?? ProcessInfo.processInfo.hostName
    #if os(OSX)
      let ipv4 = Host.current().addresses.filter { NetworkUtils.isValidIpv4Address($0) }.sorted().first
      let ipv6 = Host.current().addresses.filter { NetworkUtils.isValidIpv6Address($0) }.sorted().first
      return ZipkinEndpoint(serviceName: hostname, ipv4: ipv4, ipv6: ipv6, port: nil)
    #else
      return ZipkinEndpoint(serviceName: hostname)
    #endif
  }
}
