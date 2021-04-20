// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import NIO
import NIOHTTP1

typealias GenericCallback = () -> ()

struct HttpTestServerConfig {
    var successCallback: GenericCallback?
    var errorCallback: GenericCallback?
}

internal class HttpTestServer {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var host: String
    private var port: Int

    var config: HttpTestServerConfig?

    public init(url: URL?, config: HttpTestServerConfig?) {
        host = url?.host ?? "localhost"
        port = url?.port ?? 33333
        self.config = config
    }

    public func start() throws {
        do {
            let channel = try serverBootstrap.bind(host: host, port: port).wait()
            print("Listening on \(String(describing: channel.localAddress))...")
            try channel.closeFuture.wait()
        } catch {
            throw error
        }
    }

    public func stop() {
        do {
            try group.syncShutdownGracefully()
        } catch {
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
            .childChannelInitializer { [weak self] channel in
                // Ensure we don't read faster than we can write by adding the BackPressureHandler into the pipeline.
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(TestHTTPHandler(config: self?.config))
                }
            }

            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    }

    private final class TestHTTPHandler: ChannelInboundHandler {
        public typealias InboundIn = HTTPServerRequestPart
        public typealias OutboundOut = HTTPServerResponsePart

        var config: HttpTestServerConfig?

        init(config: HttpTestServerConfig?) {
            self.config = config
        }

        public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            let reqPart = unwrapInboundIn(data)

            switch reqPart {
                case let .head(request):

                    if request.uri.unicodeScalars.starts(with: "/success".unicodeScalars) {
                        let channel = context.channel

                        let head = HTTPResponseHead(version: request.version,
                                                    status: .ok)
                        let part = HTTPServerResponsePart.head(head)
                        _ = channel.write(part)

                        config?.successCallback?()

                        let endpart = HTTPServerResponsePart.end(nil)
                        _ = channel.writeAndFlush(endpart).flatMap {
                            channel.close()
                        }
                    } else if request.uri.unicodeScalars.starts(with: "/forbidden".unicodeScalars) {
                        let channel = context.channel

                        let head = HTTPResponseHead(version: request.version,
                                                    status: .forbidden)
                        let part = HTTPServerResponsePart.head(head)
                        _ = channel.write(part)

                        config?.errorCallback?()

                        let endpart = HTTPServerResponsePart.end(nil)
                        _ = channel.writeAndFlush(endpart).flatMap {
                            channel.close()
                        }
                    } else if request.uri.unicodeScalars.starts(with: "/error".unicodeScalars) {
                        let channel = context.channel
                        config?.errorCallback?()
                        _ = channel.close()
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
