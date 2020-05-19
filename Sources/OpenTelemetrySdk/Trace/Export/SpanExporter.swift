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

/// An interface that allows different tracing services to export recorded data for sampled spans in
/// their own format.
/// To export data this MUST be register to the TracerSdk using a SimpleSpansProcessor or
///  a  BatchSampledSpansProcessor.
public protocol SpanExporter: AnyObject {
    /// Called to export sampled Spans.
    /// - Parameter spans: the list of sampled Spans to be exported.
    @discardableResult func export(spans: [SpanData]) -> SpanExporterResultCode

    ///Exports the collection of sampled Spans that have not yet been exported.
    func flush() -> SpanExporterResultCode
    
    /// Called when TracerSdkFactory.shutdown()} is called, if this SpanExporter is registered
    ///  to a TracerSdkFactory object.
    func shutdown()
}

/// The possible results for the export method.
public enum SpanExporterResultCode {
    /// The export operation finished successfully.
    case success

    /// The export operation finished with an error.
    case failure


    /// Merges the current result code with other result code
    /// - Parameter newResultCode: the result code to merge with
    public mutating func mergeResultCode(newResultCode: SpanExporterResultCode) {
        // If both results are success then return success.
        if self == .success && newResultCode == .success {
            self = .success
            return
        }
        self = .failure
    }
}
