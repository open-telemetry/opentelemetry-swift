/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NIO
import NIOHTTP1

// Tiny HTTP server used by Scripts/run-integration-tests.sh. The demo app's
// integration scenario makes URLSession requests against GET /status/<code>
// so the URLSession instrumentation produces spans with predictable status
// codes without depending on the public internet. GET /health returns 200.
//
// Telemetry itself goes to the OpenTelemetry Collector, not here.

var port = 4319
var iterator = CommandLine.arguments.dropFirst().makeIterator()
while let argument = iterator.next() {
  guard argument == "--port", let value = iterator.next(), let parsed = Int(value) else {
    FileHandle.standardError.write(Data("usage: IntegrationStatusServer [--port <port>]\n".utf8))
    exit(2)
  }
  port = parsed
}

final class StatusHandler: ChannelInboundHandler, @unchecked Sendable {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart

  private var head: HTTPRequestHead?

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    switch unwrapInboundIn(data) {
    case let .head(head):
      self.head = head
    case .body:
      break
    case .end:
      guard let head else { return }
      let path = head.uri.split(separator: "?", maxSplits: 1).first.map(String.init) ?? head.uri
      let (status, body): (HTTPResponseStatus, String)
      if head.method == .GET, path == "/health" {
        (status, body) = (.ok, "ok\n")
      } else if head.method == .GET, path.hasPrefix("/status/"),
                let code = Int(path.dropFirst("/status/".count)), (100 ... 599).contains(code) {
        (status, body) = (HTTPResponseStatus(statusCode: code), "{\"status\":\(code)}\n")
      } else {
        (status, body) = (.notFound, "not found\n")
      }
      var headers = HTTPHeaders()
      headers.add(name: "Content-Type", value: "application/json")
      headers.add(name: "Content-Length", value: String(body.utf8.count))
      context.write(wrapOutboundOut(.head(HTTPResponseHead(version: head.version, status: status, headers: headers))), promise: nil)
      var buffer = context.channel.allocator.buffer(capacity: body.utf8.count)
      buffer.writeString(body)
      context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
      context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
      self.head = nil
    }
  }

  func errorCaught(context: ChannelHandlerContext, error: Error) {
    context.close(promise: nil)
  }
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let channel = try ServerBootstrap(group: group)
  .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
  .childChannelInitializer { channel in
    channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
      channel.pipeline.addHandler(StatusHandler())
    }
  }
  .bind(host: "127.0.0.1", port: port)
  .wait()

print("IntegrationStatusServer listening on \(channel.localAddress!)")
fflush(stdout)
signal(SIGTERM) { _ in exit(0) }
signal(SIGINT) { _ in exit(0) }
try channel.closeFuture.wait()
