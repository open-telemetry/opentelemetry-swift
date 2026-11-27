//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//

#if OTLPGRPC

import Foundation
import OpenTelemetryApi
import OpenTelemetrySdk
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterGrpc
import StdoutExporter
import GRPCCore
import GRPCNIOTransportHTTP2

/*
 Stable metrics is the working name for the otel-swift implementation of the current OpenTelemetry metrics specification.
 The existing otel-swift metric implementation is old and out-of-spec. While Stable Metrics is in an experimental phase it will maintaion
 the "stable" prefix, and can be expected to be present on overlapping constructs in the implementation.
 Expected time line will be as follows:
  Phase 1:
    Provide access to Stable Metrics along side existing Metrics. Once Stable Metrics are considered stable we will move onto phase 2.
  Phase 2:
    Mark all existing Metric APIs as deprecated. This will maintained for a period TBD
  Phase 3:
    Remove deprecated metrics api and remove Stable prefix from Stable metrics.

 Below is an example used the Stable Metrics API

 */

/*
 Basic configuration for metrics
 */
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
func basicConfiguration() throws {
  let transport = try HTTP2ClientTransport.Posix(
    target: .dns(host: "localhost", port: 8200),
    transportSecurity: .plaintext
  )

  // register view will process all instruments using `.*` regex

  OpenTelemetry.registerMeterProvider(
meterProvider: MeterProviderSdk.builder()
  .registerView(
    selector: InstrumentSelector.builder().setInstrument(name: ".*").build(),
    view: View.builder().build()
  )
  .registerMetricReader(
    reader: PeriodicMetricReaderBuilder(
      exporter: OtlpMetricExporter(transport: transport)
    )
    .build()
  )
    .build()
  )
}

func complexViewConfiguration() {
  // The example registers a View that re-configures the Gauge instrument into a sum instrument named "GaugeSum"

  OpenTelemetry.registerMeterProvider(
    meterProvider: MeterProviderSdk.builder()
      .registerView(
        selector: InstrumentSelector.builder()
          .setInstrument(name: "Gauge")
          .build(),
        view: View.builder()
          .withName(name: "GaugeSum")
          .withAggregation(
            aggregation: Aggregations
              .sum()
          )
          .build()
      )
      .setExemplarFilter(exemplarFilter: AlwaysOnFilter())
      .registerMetricReader(
        reader: PeriodicMetricReaderBuilder(
          exporter: StdoutMetricExporter(isDebug: true)
        )
        .build()
      )
      .build()
  )
}

if #available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) {
  try basicConfiguration()
} else {
  print("This example requires macOS 15, iOS 18, tvOS 18, watchOS 11 or visionOS 2.")
}

// creating a new meter & instrument
let meter = OpenTelemetry.instance.meterProvider.meterBuilder(name: "MyMeter").build()
var gaugeBuilder = meter.gaugeBuilder(name: "Gauge")

// observable gauge
var observableGauge = gaugeBuilder.buildWithCallback { ObservableDoubleMeasurement in
  ObservableDoubleMeasurement.record(value: 1.0, attributes: ["test": AttributeValue.bool(true)])
}

var gauge = meter.gaugeBuilder(name: "Gauge").buildWithCallback { _ in
  // noop
}

// gauge
// gauge.record(value: 1.0, attributes: ["test": AttributeValue.bool(true)])

#else

print("This example requires the OTLPGRPC package trait.")

#endif
