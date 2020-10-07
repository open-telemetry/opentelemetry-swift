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

/// Container with dependencies common to all features (Logging, Tracing and RUM).
internal struct FeaturesCommonDependencies {
    let performance: PerformancePreset
    let httpClient: HTTPClient
    let device: Device
    let dateProvider: DateProvider
//    let userInfoProvider: UserInfoProvider
//    let networkConnectionInfoProvider: NetworkConnectionInfoProviderType
//    let carrierInfoProvider: CarrierInfoProviderType
}

internal struct FeatureStorage {
    /// Writes data to files.
    let writer: FileWriterType
    /// Reads data from files.
    let reader: FileReaderType

    init(writer: FileWriterType, reader: FileReaderType) {
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
