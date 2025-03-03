/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

/// Describes the format of writing and reading data from files.
struct DataFormat {
  /// Prefixes the batch payload read from file.
  let prefixData: Data
  /// Suffixes the batch payload read from file.
  let suffixData: Data
  /// Separates entities written to file.
  let separatorData: Data

  // MARK: - Initialization

  init(prefix: String,
       suffix: String,
       separator: String) {
    prefixData = prefix.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
    suffixData = suffix.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
    separatorData = separator.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
  }
}
