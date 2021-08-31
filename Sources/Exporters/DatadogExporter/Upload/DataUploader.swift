/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// A type that performs data uploads.
internal protocol DataUploaderType {
    func upload(data: Data) -> DataUploadStatus
}

/// Synchronously uploads data to server using `HTTPClient`.
internal final class DataUploader: DataUploaderType {
    /// An unreachable upload status - only meant to satisfy the compiler.
    private static let unreachableUploadStatus = DataUploadStatus(needsRetry: false, userDebugDescription: "", userErrorMessage: nil)

    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder

    init(httpClient: HTTPClient, requestBuilder: RequestBuilder) {
        self.httpClient = httpClient
        self.requestBuilder = requestBuilder
    }

    /// Uploads data synchronously (will block current thread) and returns the upload status.
    /// Uses timeout configured for `HTTPClient`.
    func upload(data: Data) -> DataUploadStatus {
        let (request, ddRequestID) = createRequest(with: data)
        var uploadStatus: DataUploadStatus?

        let semaphore = DispatchSemaphore(value: 0)

        httpClient.send(request: request) { result in
            switch result {
            case .success(let httpResponse):
                uploadStatus = DataUploadStatus(httpResponse: httpResponse, ddRequestID: ddRequestID)
            case .failure(let error):
                uploadStatus = DataUploadStatus(networkError: error)
            }

            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .distantFuture)

        return uploadStatus ?? DataUploader.unreachableUploadStatus
    }

    private func createRequest(with data: Data) -> (request: URLRequest, ddRequestID: String?) {
        let request = requestBuilder.uploadRequest(with: data)
        let requestID = request.value(forHTTPHeaderField: RequestBuilder.HTTPHeader.ddRequestIDHeaderField)
        return (request: request, ddRequestID: requestID)
    }
}
