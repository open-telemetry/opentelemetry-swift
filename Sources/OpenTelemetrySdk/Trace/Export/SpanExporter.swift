/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// An interface that allows different tracing services to export recorded data for 
/// sampled spans in their own format.
/// To export data this MUST be register to the TracerSdk using a SimpleSpansProcessor or
///  a  BatchSampledSpansProcessor.
public protocol SpanExporter: AnyObject, Sendable {
  /// Called to export sampled Spans.
  /// - Parameter spans: the list of sampled Spans to be exported.
  @discardableResult func export(spans: [SpanData], explicitTimeout: TimeInterval?) -> SpanExporterResultCode

  /// Exports the collection of sampled Spans that have not yet been exported.
  func flush(explicitTimeout: TimeInterval?) -> SpanExporterResultCode

  /// Called when TracerSdkFactory.shutdown()} is called, if this SpanExporter is registered
  ///  to a TracerSdkFactory object.
  func shutdown(explicitTimeout: TimeInterval?)

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  @discardableResult func export(spans: [SpanData], explicitTimeout: TimeInterval?) async -> SpanExporterResultCode

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func flush(explicitTimeout: TimeInterval?) async -> SpanExporterResultCode

  @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
  func shutdown(explicitTimeout: TimeInterval?) async
}

public extension SpanExporter {
  func export(spans: [SpanData]) -> SpanExporterResultCode {
    return export(spans: spans, explicitTimeout: nil)
  }

  func flush() -> SpanExporterResultCode {
    return flush(explicitTimeout: nil)
  }

  func shutdown() {
    shutdown(explicitTimeout: nil)
  }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension SpanExporter {
  @discardableResult func export(spans: [SpanData], explicitTimeout: TimeInterval?) async -> SpanExporterResultCode {
    assertionFailure("async export(spans:explicitTimeout:) must be implemented by \(type(of: self))")
    return .failure
  }

  func flush(explicitTimeout: TimeInterval?) async -> SpanExporterResultCode {
    assertionFailure("async flush(explicitTimeout:) must be implemented by \(type(of: self))")
    return .failure
  }

  func shutdown(explicitTimeout: TimeInterval?) async {
    assertionFailure("async shutdown(explicitTimeout:) must be implemented by \(type(of: self))")
  }

  @discardableResult func export(spans: [SpanData]) async -> SpanExporterResultCode {
    return await export(spans: spans, explicitTimeout: nil)
  }

  func flush() async -> SpanExporterResultCode {
    return await flush(explicitTimeout: nil)
  }

  func shutdown() async {
    await shutdown(explicitTimeout: nil)
  }
}

/// The possible results for the export method.
public enum SpanExporterResultCode: Sendable {
  /// The export operation finished successfully.
  case success

  /// The export operation finished with an error.
  case failure

  /// Merges the current result code with other result code
  /// - Parameter newResultCode: the result code to merge with
  mutating func mergeResultCode(newResultCode: SpanExporterResultCode) {
    // If both results are success then return success.
    if self == .success, newResultCode == .success {
      self = .success
      return
    }
    self = .failure
  }
}
