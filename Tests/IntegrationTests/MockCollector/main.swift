/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NIO
import NIOHTTP1

// A minimal OTLP/HTTP receiver used by Scripts/run-integration-tests.sh.
//
// It accepts POST /v1/traces, /v1/logs and /v1/metrics (protobuf or JSON,
// optionally gzip/deflate encoded), decodes every request and appends it as one
// JSON line to <output-dir>/{traces,logs,metrics}.jsonl. The JSON layout is the
// OTLP proto JSON mapping, the same shape the collector's `file` exporter writes,
// so the assertions in ../Assertions work with either backend.
//
// It also serves GET /status/<code> so the app under test can make HTTP requests
// with a predictable response without depending on the public internet.

struct Options {
  var port = 4318
  var outputDirectory = URL(fileURLWithPath: "out", isDirectory: true)

  static func parse(_ arguments: [String]) -> Options {
    var options = Options()
    var iterator = arguments.dropFirst().makeIterator()
    while let argument = iterator.next() {
      switch argument {
      case "--port":
        guard let value = iterator.next(), let port = Int(value) else { usage() }
        options.port = port
      case "--output-dir":
        guard let value = iterator.next() else { usage() }
        options.outputDirectory = URL(fileURLWithPath: value, isDirectory: true)
      default:
        usage()
      }
    }
    return options
  }

  static func usage() -> Never {
    FileHandle.standardError.write(Data("usage: OTLPMockCollector [--port <port>] [--output-dir <dir>]\n".utf8))
    exit(2)
  }
}

let options = Options.parse(CommandLine.arguments)
let sink = try JSONLinesSink(directory: options.outputDirectory)
let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

let bootstrap = ServerBootstrap(group: group)
  .serverChannelOption(ChannelOptions.backlog, value: 256)
  .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
  .childChannelInitializer { channel in
    channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
      channel.pipeline.addHandler(OTLPRequestHandler(sink: sink))
    }
  }
  .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

let channel = try bootstrap.bind(host: "127.0.0.1", port: options.port).wait()
print("OTLPMockCollector listening on \(channel.localAddress!) writing to \(options.outputDirectory.path)")
fflush(stdout)

signal(SIGTERM) { _ in exit(0) }
signal(SIGINT) { _ in exit(0) }

try channel.closeFuture.wait()
