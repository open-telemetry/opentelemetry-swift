/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

private enum HTTPResponseStatusCode: Int {
  /// The request has been accepted for processing.
  case accepted = 202
  /// The server cannot or will not process the request (client error).
  case badRequest = 400
  /// The request lacks valid authentication credentials.
  case unauthorized = 401
  /// The server understood the request but refuses to authorize it.
  case forbidden = 403
  /// The server would like to shut down the connection.
  case requestTimeout = 408
  /// The request entity is larger than limits defined by server.
  case payloadTooLarge = 413
  /// The client has sent too many requests in a given amount of time.
  case tooManyRequests = 429
  /// The server encountered an unexpected condition.
  case internalServerError = 500
  /// The server is not ready to handle the request probably because it is overloaded.
  case serviceUnavailable = 503
  /// An unexpected status code.
  case unexpected = -999

  /// If it makes sense to retry the upload finished with this status code, e.g. if data upload failed due to `503` HTTP error, we should retry it later.
  var needsRetry: Bool {
    switch self {
    case .accepted, .badRequest, .unauthorized, .forbidden, .payloadTooLarge:
      // No retry - it's either success or a client error which won't be fixed in next upload.
      return false
    case .requestTimeout, .tooManyRequests, .internalServerError, .serviceUnavailable:
      // Retry - it's a temporary server or connection issue that might disappear on next attempt.
      return true
    case .unexpected:
      // This shouldn't happen, but if receiving an unexpected status code we do not retry.
      // This is safer than retrying as we don't know if the issue is coming from the client or server.
      return false
    }
  }
}

/// The status of a single upload attempt.
internal struct DataUploadStatus {
  /// If upload needs to be retried (`true`) because its associated data was not delivered but it may succeed
  /// in the next attempt (i.e. it failed due to device leaving signal range or a temporary server unavailability occurred).
  /// If set to `false` then data associated with the upload should be deleted as it does not need any more upload
  /// attempts (i.e. the upload succeeded or failed due to unrecoverable client error).
  let needsRetry: Bool
}

extension DataUploadStatus {
  // MARK: - Initialization

  init(httpResponse: HTTPURLResponse, ddRequestID: String?) {
    let statusCode = HTTPResponseStatusCode(rawValue: httpResponse.statusCode) ?? .unexpected
    self.init(needsRetry: statusCode.needsRetry)
  }

  init(networkError: Error) {
    self.init(needsRetry: true)
  }
}
