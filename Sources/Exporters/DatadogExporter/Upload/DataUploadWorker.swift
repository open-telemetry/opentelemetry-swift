/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

/// Abstracts the `DataUploadWorker`, so we can have no-op uploader in tests.
internal protocol DataUploadWorkerType {
  func flush() -> SpanExporterResultCode
}

internal class DataUploadWorker: DataUploadWorkerType {
  /// Queue to execute uploads.
  internal let queue = DispatchQueue(label: "com.otel.datadog.datauploadworker", target: .global(qos: .utility))
  /// File reader providing data to upload.
  private let fileReader: FileReader
  /// Data uploader sending data to server.
  private let dataUploader: DataUploaderType
  /// Variable system conditions determining if upload should be performed.
  private let uploadCondition: () -> Bool

  /// Name of the feature this worker is performing uploads for.
  private let featureName: String

  /// Delay used to schedule consecutive uploads.
  private var delay: Delay

  /// Upload work scheduled by this worker.
  private var uploadWork: DispatchWorkItem?

  init(
    fileReader: FileReader,
    dataUploader: DataUploaderType,
    uploadCondition: @escaping () -> Bool,
    delay: Delay,
    featureName: String
  ) {
    self.fileReader = fileReader
    self.uploadCondition = uploadCondition
    self.dataUploader = dataUploader
    self.delay = delay
    self.featureName = featureName

    let uploadWork = DispatchWorkItem { [weak self] in
      guard let self = self else {
        return
      }

      let isSystemReady = self.uploadCondition()
      let nextBatch = isSystemReady ? self.fileReader.readNextBatch() : nil
      if let batch = nextBatch {
        // Upload batch
        let uploadStatus = self.dataUploader.upload(data: batch.data)

        // Delete or keep batch depending on the upload status
        if uploadStatus.needsRetry {
          self.delay.increase()

        } else {
          self.fileReader.markBatchAsRead(batch)
          self.delay.decrease()
        }
      } else {
        self.delay.increase()
      }

      self.scheduleNextUpload(after: self.delay.current)
    }

    self.uploadWork = uploadWork

    scheduleNextUpload(after: self.delay.current)
  }

  private func scheduleNextUpload(after delay: TimeInterval) {
    guard let work = uploadWork else {
      return
    }

    queue.asyncAfter(deadline: .now() + delay, execute: work)
  }

  /// This method  gets remaining files at once, and uploads them
  /// It assures that periodic uploader cannot read or upload the files while the flush is being processed
  internal func flush() -> SpanExporterResultCode {
    let success = queue.sync {
      self.fileReader.onRemainingBatches {
        let uploadStatus = self.dataUploader.upload(data: $0.data)
        if !uploadStatus.needsRetry {
          self.fileReader.markBatchAsRead($0)
        }
      }
    }
    return success ? .success : .failure
  }

  /// Cancels scheduled uploads and stops scheduling next ones.
  /// - It does not affect the upload that has already begun.
  /// - It blocks the caller thread if called in the middle of upload execution.
  internal func cancelSynchronously() {
    queue.sync {
      // This cancellation must be performed on the `queue` to ensure that it is not called
      // in the middle of a `DispatchWorkItem` execution - otherwise, as the pending block would be
      // fully executed, it will schedule another upload by calling `nextScheduledWork(after:)` at the end.
      self.uploadWork?.cancel()
      self.uploadWork = nil
    }
  }
}
