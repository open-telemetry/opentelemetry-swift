/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import Foundation

/*
 Set of Persistence domain extensions over standard types for writing more readable tests.
 Domain agnostic extensions should be put in `SwiftExtensions.swift`.
 */

extension Date {
  /// Returns name of the logs file createde at this date.
  var toFileName: String {
    return fileNameFrom(fileCreationDate: self)
  }
}

extension File {
  func makeReadonly() throws {
    try FileManager.default.setAttributes([.immutable: true], ofItemAtPath: url.path)
  }

  func makeReadWrite() throws {
    try FileManager.default.setAttributes([.immutable: false], ofItemAtPath: url.path)
  }
}
