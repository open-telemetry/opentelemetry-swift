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

    init(writer: FileWriter, reader: FileReader) {
        self.writer = writer
        self.reader = reader
    }
}

internal struct FeatureUpload {
    /// Uploads data to server.
    let uploader: DataUploadWorkerType

    init(
        featureName: String,
        storage: FeatureStorage,
        uploadHTTPHeaders: HTTPHeaders,
        uploadURLProvider: UploadURLProvider,
        performance: PerformancePreset,
        uploadCondition: @escaping () -> Bool
    ) {
        let uploadQueue = DispatchQueue(
            label: "com.datadoghq.ios-sdk-\(featureName)-upload",
            target: .global(qos: .utility)
        )

        let dataUploader = DataUploader(
            urlProvider: uploadURLProvider,
            httpClient: HTTPClient(),
            httpHeaders: uploadHTTPHeaders
        )

        self.init(
            uploader: DataUploadWorker(
                queue: uploadQueue,
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
