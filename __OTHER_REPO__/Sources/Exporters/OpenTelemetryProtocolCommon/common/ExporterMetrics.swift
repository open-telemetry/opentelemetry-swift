//
// Copyright The OpenTelemetry Authors
// SPDX-License-Identifier: Apache-2.0
//
import Foundation
import OpenTelemetryApi

/// `ExporterMetrics` will provide a way to track how many data have been seen or successfully exported,
/// as well as how many failed. The exporter will adopt an instance of this and inject the provider as a dependency.
/// The host application can then track different types of exporters, such as `http, grpc, and log`
public class ExporterMetrics {
  public enum TransporterType: String {
    case grpc
    case protoBuf = "http"
    case httpJson = "http-json"
  }

  public static let ATTRIBUTE_KEY_TYPE: String = "type"
  public static let ATTRIBUTE_KEY_SUCCESS: String = "success"

  private let meterProvider: any MeterProvider
  private let exporterName: String
  private let transportName: String
  private var seenAttrs: [String: AttributeValue] = [:]
  private var successAttrs: [String: AttributeValue] = [:]
  private var failedAttrs: [String: AttributeValue] = [:]

  private var seen: LongCounter?
  private var exported: LongCounter?

  /// - Parameters:
  ///    - type: That represent what type of exporter it is. `otlp`
  ///    - meterProvider: Injected `StableMeterProvider` for metric
  ///    - exporterName: Could be `span`, `log` etc
  ///    - transportName: Kind of exporter defined by type `TransporterType`
  public init(type: String,
              meterProvider: any MeterProvider,
              exporterName: String,
              transportName: TransporterType) {
    self.meterProvider = meterProvider
    self.exporterName = exporterName
    self.transportName = transportName.rawValue
    seenAttrs = [
      ExporterMetrics.ATTRIBUTE_KEY_TYPE: .string(type)
    ]
    successAttrs = [
      ExporterMetrics.ATTRIBUTE_KEY_SUCCESS: .bool(true)
    ]
    failedAttrs = [
      ExporterMetrics.ATTRIBUTE_KEY_SUCCESS: .bool(false)
    ]

    seen = meter.counterBuilder(name: "\(exporterName).exporter.seen").build()
    exported = meter.counterBuilder(name: "\(exporterName).exporter.exported").build()
  }

  public func addSeen(value: Int) {
    seen?.add(value: value, attributes: seenAttrs)
  }

  public func addSuccess(value: Int) {
    exported?.add(value: value, attributes: successAttrs)
  }

  public func addFailed(value: Int) {
    exported?.add(value: value, attributes: failedAttrs)
  }

  // MARK: - Private functions

  /***
   * Create an instance for recording exporter metrics under the meter
   * "io.opentelemetry.exporters." + exporterName + "-transporterType".
   **/
  private var meter: any Meter {
    meterProvider.get(name: "io.opentelemetry.exporters.\(exporterName)-\(transportName)")
  }

  // MARK: - Static function

  public static func makeExporterMetric(type: String,
                                        meterProvider: any MeterProvider,
                                        exporterName: String,
                                        transportName: TransporterType) -> ExporterMetrics {
    ExporterMetrics(type: type,
                    meterProvider: meterProvider,
                    exporterName: exporterName,
                    transportName: transportName)
  }
}
