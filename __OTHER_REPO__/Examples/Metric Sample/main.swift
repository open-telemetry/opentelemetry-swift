//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk

func configure() {
  let configuration = ClientConnection.Configuration.default(target: .hostAndPort("localhost", 4317),
                                                             eventLoopGroup: MultiThreadedEventLoopGroup(numberOfThreads: 1))
  let client = ClientConnection(configuration: configuration)

  let resource = Resource(attributes: ["service.name": "StableMetricExample"]).merge(other: resource())

  OpenTelemetry.registerMeterProvider(meterProvider: StableMeterProviderSdk.builder().
    registerMetricReader(reader: StablePeriodicMetricReaderBuilder(exporter: StableOtlpMetricExporter(channel: client))
      .setInterval(timeInterval: 60).build()).build())
}

configure()
