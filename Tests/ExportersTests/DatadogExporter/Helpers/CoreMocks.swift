/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import DatadogExporter
import Foundation

// MARK: - PerformancePreset Mocks

struct StoragePerformanceMock: StoragePerformancePreset {
  let maxFileSize: UInt64
  let maxDirectorySize: UInt64
  let maxFileAgeForWrite: TimeInterval
  let minFileAgeForRead: TimeInterval
  let maxFileAgeForRead: TimeInterval
  let maxObjectsInFile: Int
  let maxObjectSize: UInt64

  static let readAllFiles = StoragePerformanceMock(
    maxFileSize: .max,
    maxDirectorySize: .max,
    maxFileAgeForWrite: 0,
    minFileAgeForRead: -1, // make all files eligible for read
    maxFileAgeForRead: .distantFuture, // make all files eligible for read
    maxObjectsInFile: .max,
    maxObjectSize: .max
  )

  static let writeEachObjectToNewFileAndReadAllFiles = StoragePerformanceMock(
    maxFileSize: .max,
    maxDirectorySize: .max,
    maxFileAgeForWrite: 0, // always return new file for writing
    minFileAgeForRead: readAllFiles.minFileAgeForRead,
    maxFileAgeForRead: readAllFiles.maxFileAgeForRead,
    maxObjectsInFile: 1, // write each data to new file
    maxObjectSize: .max
  )
}

struct UploadPerformanceMock: UploadPerformancePreset {
  let initialUploadDelay: TimeInterval
  let defaultUploadDelay: TimeInterval
  let minUploadDelay: TimeInterval
  let maxUploadDelay: TimeInterval
  let uploadDelayChangeRate: Double

  static let veryQuick = UploadPerformanceMock(
    initialUploadDelay: 0.05,
    defaultUploadDelay: 0.05,
    minUploadDelay: 0.05,
    maxUploadDelay: 0.05,
    uploadDelayChangeRate: 0
  )
}

extension DataFormat {
  static func mockAny() -> DataFormat {
    return mockWith()
  }

  static func mockWith(
    prefix: String = .mockAny(),
    suffix: String = .mockAny(),
    separator: String = .mockAny()
  ) -> DataFormat {
    return DataFormat(
      prefix: prefix,
      suffix: suffix,
      separator: separator
    )
  }
}

/// `DateProvider` mock returning consecutive dates in custom intervals, starting from given reference date.
class RelativeDateProvider: DateProvider {
  private(set) var date: Date
  internal let timeInterval: TimeInterval
  private let queue = DispatchQueue(label: "queue-RelativeDateProvider-\(UUID().uuidString)")

  private init(date: Date, timeInterval: TimeInterval) {
    self.date = date
    self.timeInterval = timeInterval
  }

  convenience init(using date: Date = Date()) {
    self.init(date: date, timeInterval: 0)
  }

  convenience init(startingFrom referenceDate: Date = Date(), advancingBySeconds timeInterval: TimeInterval = 0) {
    self.init(date: referenceDate, timeInterval: timeInterval)
  }

  /// Returns current date and advances next date by `timeInterval`.
  func currentDate() -> Date {
    defer {
      queue.async {
        self.date.addTimeInterval(self.timeInterval)
      }
    }
    return queue.sync {
      return date
    }
  }

  /// Pushes time forward by given number of seconds.
  func advance(bySeconds seconds: TimeInterval) {
    queue.async {
      self.date = self.date.addingTimeInterval(seconds)
    }
  }
}

extension RequestBuilder: AnyMockable {
  static func mockAny() -> RequestBuilder {
    return mockWith()
  }

  static func mockWith(
    url: URL = .mockAny(),
    queryItems: [QueryItem] = [],
    headers: [HTTPHeader] = []
  ) -> RequestBuilder {
    return RequestBuilder(url: url, queryItems: queryItems, headers: headers)
  }
}

extension HTTPClient {
  static func mockAny() -> HTTPClient {
    return HTTPClient(session: URLSession(configuration: URLSessionConfiguration.default))
  }
}

extension Device {
  static func mockAny() -> Device {
    return .mockWith()
  }

  static func mockWith(
    model: String = .mockAny(),
    osName: String = .mockAny(),
    osVersion: String = .mockAny()
  ) -> Device {
    return Device(
      model: model,
      osName: osName,
      osVersion: osVersion
    )
  }
}

struct DataUploaderMock: DataUploaderType {
  let uploadStatus: DataUploadStatus

  var onUpload: (() -> Void)? = nil

  func upload(data: Data) -> DataUploadStatus {
    onUpload?()
    return uploadStatus
  }
}

extension DataUploadStatus: RandomMockable {
  static func mockRandom() -> DataUploadStatus {
    let retryRandom: Bool = .random()
    return DataUploadStatus(needsRetry: retryRandom)
  }

  static func mockWith(
    needsRetry: Bool = .mockAny(),
    accepted: Bool = true
  ) -> DataUploadStatus {
    return DataUploadStatus(needsRetry: needsRetry)
  }
}
