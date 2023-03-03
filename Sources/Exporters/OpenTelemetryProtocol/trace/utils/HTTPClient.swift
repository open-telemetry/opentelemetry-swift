/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Client for sending requests over HTTP.
internal final class HTTPClient {
    private let session: URLSession

    convenience init() {
        let configuration: URLSessionConfiguration = .ephemeral
        // NOTE: RUMM-610 Default behaviour of `.ephemeral` session is to cache requests.
        // To not leak requests memory (including their `.httpBody` which may be significant)
        // we explicitly opt-out from using cache. This cannot be achieved using `.requestCachePolicy`.
        configuration.urlCache = nil
        // TODO: RUMM-123 Optimize `URLSessionConfiguration` for good traffic performance
        // and move session configuration constants to `PerformancePreset`.
        self.init(session: URLSession(configuration: configuration))
    }

    init(session: URLSession) {
        self.session = session
    }

    func send(request: URLRequest, completion: @escaping (Result<HTTPURLResponse, Error>) -> Void) {
        let task = session.dataTask(with: request) { data, response, error in
            completion(httpClientResult(for: (data, response, error)))
        }
        task.resume()
    }
}

/// An error returned if `URLSession` response state is inconsistent (like no data, no response and no error).
/// The code execution in `URLSessionTransport` should never reach its initialization.
internal struct URLSessionTransportInconsistencyException: Error {}

/// As `URLSession` returns 3-values-tuple for request execution, this function applies consistency constraints and turns
/// it into only two possible states of `HTTPTransportResult`.
private func httpClientResult(for urlSessionTaskCompletion: (Data?, URLResponse?, Error?)) -> Result<HTTPURLResponse, Error> {
    let (_, response, error) = urlSessionTaskCompletion

    if let error = error {
        return .failure(error)
    }

    if let httpResponse = response as? HTTPURLResponse {
        return .success(httpResponse)
    }

    return .failure(URLSessionTransportInconsistencyException())
}
