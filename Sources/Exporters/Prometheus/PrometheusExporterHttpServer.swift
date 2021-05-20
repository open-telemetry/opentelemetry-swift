/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NIO
import NIOHTTP1

public class PrometheusExporterHttpServer {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var host: String
    private var port: Int
    var exporter: PrometheusExporter

    public init(exporter: PrometheusExporter) {
        self.exporter = exporter

        let url = URL(string: exporter.options.url)
        host = url?.host ?? "localhost"
        port = url?.port ?? 9184
    }

    public func start() throws {
        do {
            let channel = try serverBootstrap.bind(host: host, port: port).wait()
            print("Listening on \(String(describing: channel.localAddress))...")
            try channel.closeFuture.wait()
        } catch let error {
            throw error
        }
    }

    public func stop() {
        do {
            try group.syncShutdownGracefully()
        } catch let error {
            print("Error shutting down \(error.localizedDescription)")
            exit(0)
        }
        print("Client connection closed")
    }

    private var serverBootstrap: ServerBootstrap {
        return ServerBootstrap(group: group)
            // Specify backlog and enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

            // Set the handlers that are appled to the accepted Channels
            .childChannelInitializer { channel in
                // Ensure we don't read faster than we can write by adding the BackPressureHandler into the pipeline.
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(PrometheusHTTPHandler(exporter: self.exporter))
                }
            }

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    }

    private final class PrometheusHTTPHandler: ChannelInboundHandler {
        public typealias InboundIn = HTTPServerRequestPart
        public typealias OutboundOut = HTTPServerResponsePart

        var exporter: PrometheusExporter

        init(exporter: PrometheusExporter) {
            self.exporter = exporter
        }

        public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let reqPart = unwrapInboundIn(data)

            switch reqPart {
            case let .head(request):

                if request.uri.unicodeScalars.starts(with: "/metrics".unicodeScalars) {
                    let channel = context.channel

                    let head = HTTPResponseHead(version: request.version,
                                                status: .ok)
                    let part = HTTPServerResponsePart.head(head)
                    _ = channel.write(part)

                    let metrics = PrometheusExporterExtensions.writeMetricsCollection(exporter: exporter)
                    var buffer = channel.allocator.buffer(capacity: metrics.count)
                    buffer.writeString(metrics)
                    let bodypart = HTTPServerResponsePart.body(.byteBuffer(buffer))
                    _ = channel.write(bodypart)

                    let endpart = HTTPServerResponsePart.end(nil)
                    _ = channel.writeAndFlush(endpart).flatMap {
                        channel.close()
                    }
                }

            case .body:
                break
            case .end: break
            }
        }

        // Flush it out. This can make use of gathering writes if multiple buffers are pending
        public func channelReadComplete(context: ChannelHandlerContext) {
            context.flush()
        }

        public func errorCaught(context: ChannelHandlerContext, error: Error) {
            print("error: ", error)

            // As we are not really interested getting notified on success or failure we just pass nil as promise to
            // reduce allocations.
            context.close(promise: nil)
        }
    }
}
