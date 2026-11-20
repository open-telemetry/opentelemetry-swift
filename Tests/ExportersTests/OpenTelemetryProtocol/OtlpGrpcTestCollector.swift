/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if OTLPGRPC

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class OtlpGrpcTestServer<Service: RegistrableRPCService>: Sendable {
  let port: Int
  private let server: GRPCServer<HTTP2ServerTransport.Posix>
  private let serveTask: Task<Void, Never>

  init(service: Service, compression: CompressionAlgorithmSet = .none) async throws {
    let transport = HTTP2ServerTransport.Posix(
      address: .ipv4(host: "127.0.0.1", port: 0),
      transportSecurity: .plaintext,
      config: .defaults { $0.compression.enabledAlgorithms = compression }
    )
    let server = GRPCServer(transport: transport, services: [service])
    let serveTask = Task { _ = try? await server.serve() }
    guard let port = try await transport.listeningAddress.ipv4?.port else {
      serveTask.cancel()
      throw RPCError(code: .unavailable, message: "The test server did not bind an IPv4 address.")
    }
    self.port = port
    self.server = server
    self.serveTask = serveTask
  }

  func makeClientTransport(compression: CompressionAlgorithmSet = .none) throws -> HTTP2ClientTransport.Posix {
    try HTTP2ClientTransport.Posix(
      target: .ipv4(address: "127.0.0.1", port: port),
      transportSecurity: .plaintext,
      config: .defaults { $0.compression = .init(algorithm: .none, enabledAlgorithms: compression) }
    )
  }

  func stop() async {
    server.beginGracefulShutdown()
    await serveTask.value
  }
}

#endif
