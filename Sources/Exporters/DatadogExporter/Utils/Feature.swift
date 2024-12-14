/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Container with dependencies common to all features (Logging, Tracing and RUM).
internal struct FeaturesCommonDependencies {
    let performance: PerformancePreset
    let httpClient: HTTPClient
    let device: Device
    let dateProvider: DateProvider
}

internal struct FeatureStorage {
    /// Writes data to files.
    let writer: FileWriter
    /// Reads data from files.
    let reader: FileReader
}

internal struct FeatureUpload {
    /// Uploads data to server.
    let uploader: DataUploadWorkerType

    init(
        featureName: String,
        storage: FeatureStorage,
        requestBuilder: RequestBuilder,
        performance: PerformancePreset,
        uploadCondition: @escaping () -> Bool
    ) {
        let dataUploader = DataUploader(
            httpClient: HTTPClient(),
            requestBuilder: requestBuilder
        )

        self.init(
            uploader: DataUploadWorker(
                fileReader: storage.reader,
                dataUploader: dataUploader,
                uploadCondition: uploadCondition,
                delay: DataUploadDelay(performance: performance),
                featureName: featureName
            )
        )
    }

    init(uploader: DataUploadWorkerType) {
        self.uploader = uploader
    }
}
