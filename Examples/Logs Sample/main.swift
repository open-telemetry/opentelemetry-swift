//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

#if OTLPGRPC

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterGrpc
import GRPCCore
import GRPCNIOTransportHTTP2

if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) {
  func configure() throws {
    let transport = try HTTP2ClientTransport.Posix(
      target: .dns(host: "localhost", port: 4317),
      transportSecurity: .plaintext
    )

    OpenTelemetry.registerLoggerProvider(loggerProvider: LoggerProviderBuilder().with(processors: [
      BatchLogRecordProcessor(logRecordExporter: OtlpLogExporter(transport: transport))
    ]).build())
  }

  try configure()

  _ = OpenTelemetry.instance.loggerProvider.loggerBuilder(instrumentationScopeName: "myScope").setEventDomain("device").build()
} else {
  print("This example requires macOS 15, iOS 18, tvOS 18, watchOS 11 or visionOS 2.")
}

#else

print("This example requires the OTLPGRPC package trait.")

#endif
