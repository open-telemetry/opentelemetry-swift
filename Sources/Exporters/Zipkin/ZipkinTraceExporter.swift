/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

public class ZipkinTraceExporter: SpanExporter {
    public var options: ZipkinTraceExporterOptions
    var localEndPoint: ZipkinEndpoint

    public init(options: ZipkinTraceExporterOptions) {
        self.options = options
        localEndPoint = ZipkinTraceExporter.getLocalZipkinEndpoint(name: options.serviceName)
    }

  public func export(spans: [SpanData], explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        guard let url = URL(string: self.options.endpoint) else { return .failure }

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

        var status: SpanExporterResultCode = .failure

        let sem = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            if error != nil {
                status = .failure
            } else {
                status = .success
            }
            sem.signal()
        }
        task.resume()
        sem.wait()

        return status
    }

  public func flush(explicitTimeout: TimeInterval? = nil) -> SpanExporterResultCode {
        return .success
    }

    public func shutdown(explicitTimeout: TimeInterval? = nil) {
    }

    func encodeSpans(spans: [SpanData]) -> [ZipkinSpan] {
        return spans.map { ZipkinConversionExtension.toZipkinSpan(otelSpan: $0, defaultLocalEndpoint: localEndPoint) }
    }

    static func getLocalZipkinEndpoint(name: String? = nil) -> ZipkinEndpoint {
        let hostname = name ?? ProcessInfo.processInfo.hostName
        #if os(OSX)
        let ipv4 = Host.current().addresses.filter{ NetworkUtils.isValidIpv4Address($0) }.sorted().first
            let ipv6 = Host.current().addresses.filter { NetworkUtils.isValidIpv6Address($0) }.sorted().first
            return ZipkinEndpoint(serviceName: hostname, ipv4: ipv4, ipv6: ipv6, port: nil)
        #else
            return ZipkinEndpoint(serviceName: hostname)
        #endif
    }
}
