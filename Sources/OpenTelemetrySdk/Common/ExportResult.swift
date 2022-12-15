/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

public enum ExportResult {
    /// The export operation finished successfully.
    case success
    /// The export operation finished with an error.
    case failure


    /// Merges the current result code with other result code
    /// - Parameter newResultCode: the result code to merge with
    mutating func mergeResultCode(newResultCode: ExportResult) {
        // If both results are success then return success.
        if self == .success && newResultCode == .success {
            self = .success
            return
        }
        self = .failure
    }
}
