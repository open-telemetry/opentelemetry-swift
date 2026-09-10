/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NIO
import NIOHTTP1
import OpenTelemetryProtocolExporterCommon
import SwiftProtobuf

final class OTLPRequestHandler: ChannelInboundHandler, @unchecked Sendable {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart

  private enum Signal: String {
    case traces = "/v1/traces"
    case logs = "/v1/logs"
    case metrics = "/v1/metrics"

    var fileName: String { "\(String(describing: self)).jsonl" }
  }

  private let sink: JSONLinesSink
  private var head: HTTPRequestHead?
  private var body = Data()

  init(sink: JSONLinesSink) {
    self.sink = sink
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    switch unwrapInboundIn(data) {
    case let .head(head):
      self.head = head
      body.removeAll(keepingCapacity: true)
    case var .body(buffer):
      if let bytes = buffer.readBytes(length: buffer.readableBytes) {
        body.append(contentsOf: bytes)
      }
    case .end:
      guard let head else { return }
      let (status, responseBody, contentType) = handle(head: head, body: body)
      respond(context: context, version: head.version, status: status, body: responseBody, contentType: contentType)
      self.head = nil
    }
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    FileHandle.standardError.write(Data("OTLPMockCollector: \(error)\n".utf8))
    context.close(promise: nil)
  }

  private func handle(head: HTTPRequestHead, body: Data) -> (HTTPResponseStatus, String, String) {
    let path = head.uri.split(separator: "?", maxSplits: 1).first.map(String.init) ?? head.uri

    if head.method == .GET, path == "/health" {
      return (.ok, "ok\n", "text/plain")
    }

    if head.method == .GET, path.hasPrefix("/status/"),
       let code = Int(path.dropFirst("/status/".count)),
       (100 ... 599).contains(code) {
      return (HTTPResponseStatus(statusCode: code), "{\"status\":\(code)}\n", "application/json")
    }

    guard head.method == .POST, let signal = Signal(rawValue: path) else {
      return (.notFound, "not found\n", "text/plain")
    }

    do {
      let payload = try Decompression.decode(body, contentEncoding: head.headers.first(name: "Content-Encoding"))
      let json = try decodeToJSON(signal: signal, payload: payload, contentType: head.headers.first(name: "Content-Type"))
      try sink.append(line: json, to: signal.fileName)
      return (.ok, "", "application/x-protobuf")
    } catch {
      FileHandle.standardError.write(Data("OTLPMockCollector: failed to handle \(path): \(error)\n".utf8))
      return (.badRequest, "\(error)\n", "text/plain")
    }
  }

  private func decodeToJSON(signal: Signal, payload: Data, contentType: String?) throws -> Data {
    let isJSON = contentType?.lowercased().contains("json") ?? false
    var options = JSONEncodingOptions()
    options.preserveProtoFieldNames = false

    func roundTrip<M: SwiftProtobuf.Message>(_: M.Type) throws -> Data {
      let message = isJSON ? try M(jsonUTF8Data: payload) : try M(serializedBytes: payload)
      return try message.jsonUTF8Data(options: options)
    }

    switch signal {
    case .traces:
      return try roundTrip(Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest.self)
    case .logs:
      return try roundTrip(Opentelemetry_Proto_Collector_Logs_V1_ExportLogsServiceRequest.self)
    case .metrics:
      return try roundTrip(Opentelemetry_Proto_Collector_Metrics_V1_ExportMetricsServiceRequest.self)
    }
  }

  private func respond(context: ChannelHandlerContext, version: HTTPVersion, status: HTTPResponseStatus, body: String, contentType: String) {
    var headers = HTTPHeaders()
    headers.add(name: "Content-Type", value: contentType)
    headers.add(name: "Content-Length", value: String(body.utf8.count))
    context.write(wrapOutboundOut(.head(HTTPResponseHead(version: version, status: status, headers: headers))), promise: nil)
    var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
    buffer.writeString(body)
    context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
    context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
  }
}
