//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
// 

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterGrpc
import Logging
import GRPC
import NIO


func configure() {
  let configuration = ClientConnection.Configuration.default(
      target: .hostAndPort("localhost", 4317),
      eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1))

      
  _ = OtlpLogExporter(channel: ClientConnection(configuration: configuration))
  
      OpenTelemetry.registerLoggerProvider(loggerProvider: LoggerProviderBuilder().with(processors: [
        BatchLogRecordProcessor(logRecordExporter:OtlpLogExporter(channel: ClientConnection(configuration: configuration)))]).build())
      
  }

  configure()
        
  let eventProvider = OpenTelemetry.instance.loggerProvider.loggerBuilder(instrumentationScopeName: "myScope").setEventDomain("device").build()
      
      
