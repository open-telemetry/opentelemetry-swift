/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// The status of a single export attempt.
struct DataExportStatus {
  /// If export needs to be retried (`true`) because its associated data was not delivered but it may succeed
  /// in the next attempt (i.e. it failed due to device leaving signal range or a temporary server unavailability occurred).
  /// If set to `false` then data associated with the upload should be deleted as it does not need any more export
  /// attempts (i.e. the upload succeeded or failed due to unrecoverable client error).
  let needsRetry: Bool
}
