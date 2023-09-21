/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// An interface that allows different tracing services to export recorded data for sampled spans in
/// their own format.
/// To export data this MUST be register to the TracerSdk using a SimpleSpansProcessor or
///  a  BatchSampledSpansProcessor.
public protocol SpanExporter: AnyObject {
  /// Called to export sampled Spans.
  /// - Parameter spans: the list of sampled Spans to be exported.
  @discardableResult func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode
  
  ///Exports the collection of sampled Spans that have not yet been exported.
  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode
  
  /// Called when TracerSdkFactory.shutdown()} is called, if this SpanExporter is registered
  ///  to a TracerSdkFactory object.
  func shutdown(explicitTimeout: TimeInterval?)
}

public extension SpanExporter {
  func export(spans: [SpanData]) -> SpanExporterResultCode {
    return export(spans: spans, explicitTimeout:nil)
  }
  func flush() -> SpanExporterResultCode {
    return flush(explicitTimeout: nil)
  }
  func shutdown() {
    shutdown(explicitTimeout: nil)
  }
}

/// The possible results for the export method.
public enum SpanExporterResultCode {
  /// The export operation finished successfully.
  case success
  
  /// The export operation finished with an error.
  case failure
  
  /// Merges the current result code with other result code
  /// - Parameter newResultCode: the result code to merge with
  mutating func mergeResultCode(newResultCode: SpanExporterResultCode) {
    // If both results are success then return success.
    if self == .success && newResultCode == .success {
      self = .success
      return
    }
    self = .failure
  }
}
