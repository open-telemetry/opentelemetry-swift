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
    private let queue: DispatchQueue
    /// File reader providing data to upload.
    private let fileReader: FileReader
    /// Data uploader sending data to server.
    private let dataUploader: DataUploader
    /// Variable system conditions determining if upload should be performed.
    private let uploadCondition: () -> Bool
    /// For each file upload, the status is checked against this list of acceptable statuses.
    /// If it's there, the file will be deleted. If not, it will be retried in next upload.
    private let acceptableUploadStatuses: Set<DataUploadStatus> = [
        .success, .redirection, .clientError, .unknown
    ]
    /// Name of the feature this worker is performing uploads for.
    private let featureName: String

    /// Delay used to schedule consecutive uploads.
    private var delay: Delay

    init(
        queue: DispatchQueue,
        fileReader: FileReader,
        dataUploader: DataUploader,
        uploadCondition: @escaping () -> Bool,
        delay: Delay,
        featureName: String
    ) {
        self.queue = queue
        self.fileReader = fileReader
        self.uploadCondition = uploadCondition
        self.dataUploader = dataUploader
        self.delay = delay
        self.featureName = featureName

        scheduleNextUpload(after: self.delay.current)
    }

    private func scheduleNextUpload(after delay: TimeInterval) {
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else {
                return
            }

            let isSystemReady = self.uploadCondition()
            let nextBatch = isSystemReady ? self.fileReader.readNextBatch() : nil

            if let batch = nextBatch {
                let uploadStatus = self.dataUploader.upload(data: batch.data)
                let shouldBeAccepted = self.acceptableUploadStatuses.contains(uploadStatus)

                if shouldBeAccepted {
                    self.fileReader.markBatchAsRead(batch)
                    self.delay.decrease()
                } else {
                    self.delay.increase()
                }
            } else {
                self.delay.increase()
            }

            self.scheduleNextUpload(after: self.delay.current)
        }
    }

    /// This method  gets remaining files at once, and uploads them
    /// It assures that periodic uploader cannot read or upload the files while the flush is being processed
    internal func flush() -> SpanExporterResultCode {
        let success = queue.sync {
            self.fileReader.onRemainingBatches {
                let uploadStatus = self.dataUploader.upload(data: $0.data)
                let shouldBeAccepted = self.acceptableUploadStatuses.contains(uploadStatus)
                if shouldBeAccepted {
                    self.fileReader.synchronizedMarkBatchAsRead($0)
                }
            }
        }
        return success ? .success : .failure
    }
}
