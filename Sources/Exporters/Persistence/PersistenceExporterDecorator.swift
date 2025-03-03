/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import OpenTelemetrySdk

// protocol for exporters that can be decorated with `PersistenceExporterDecorator`
protocol DecoratedExporter {
  associatedtype SignalType

  func export(values: [SignalType]) -> DataExportStatus
}

// a generic decorator of `DecoratedExporter` adding filesystem persistence of batches of `[T.SignalType]`.
// `T.SignalType` must conform to `Codable`.
class PersistenceExporterDecorator<T>
  where T: DecoratedExporter, T.SignalType: Codable {
  // a wrapper of `DecoratedExporter` (T) to add conformance to `DataExporter` that can be
  // used with `DataExportWorker`.
  private class DecoratedDataExporter: DataExporter {
    private let decoratedExporter: T

    init(decoratedExporter: T) {
      self.decoratedExporter = decoratedExporter
    }

    func export(data: Data) -> DataExportStatus {
      // decode batches of `[T.SignalType]` from the raw data.
      // the data is made of batches of comma-suffixed JSON arrays, so in order to utilize
      // `JSONDecoder`, add a "[" prefix and "null]" suffix making the data a valid
      // JSON array of `[T.SignalType]`.
      var arrayData: Data = JSONDataConstants.arrayPrefix
      arrayData.append(data)
      arrayData.append(JSONDataConstants.arraySuffix)

      do {
        let decoder = JSONDecoder()
        let exportables = try decoder.decode([[T.SignalType]?].self,
                                             from: arrayData).compactMap { $0 }.flatMap { $0 }

        return decoratedExporter.export(values: exportables)
      } catch {
        return DataExportStatus(needsRetry: false)
      }
    }
  }

  private let performancePreset: PersistencePerformancePreset

  private let fileWriter: FileWriter

  private let worker: DataExportWorkerProtocol

  public convenience init(decoratedExporter: T,
                          storageURL: URL,
                          exportCondition: @escaping () -> Bool = { true },
                          performancePreset: PersistencePerformancePreset = .default) {
    // orchestrate writes and reads over the folder given by `storageURL`
    let filesOrchestrator = FilesOrchestrator(directory: Directory(url: storageURL),
                                              performance: performancePreset,
                                              dateProvider: SystemDateProvider())

    let fileWriter = OrchestratedFileWriter(
      orchestrator: filesOrchestrator
    )

    let fileReader = OrchestratedFileReader(
      orchestrator: filesOrchestrator
    )

    self.init(decoratedExporter: decoratedExporter,
              fileWriter: fileWriter,
              workerFactory: {
                DataExportWorker(fileReader: fileReader,
                                 dataExporter: $0,
                                 exportCondition: exportCondition,
                                 delay: DataExportDelay(performance: performancePreset))
              },
              performancePreset: performancePreset)
  }

  // internal initializer for testing that accepts a worker factory that allows mocking the worker
  init(decoratedExporter: T,
       fileWriter: FileWriter,
       workerFactory createWorker: (DataExporter) -> DataExportWorkerProtocol,
       performancePreset: PersistencePerformancePreset) {
    self.performancePreset = performancePreset

    self.fileWriter = fileWriter

    worker = createWorker(
      DecoratedDataExporter(decoratedExporter: decoratedExporter))
  }

  public func export(values: [T.SignalType]) throws {
    let encoder = JSONEncoder()
    var data = try encoder.encode(values)
    data.append(JSONDataConstants.arraySeparator)

    if performancePreset.synchronousWrite {
      fileWriter.writeSync(data: data)
    } else {
      fileWriter.write(data: data)
    }
  }

  public func flush() {
    fileWriter.flush()
    _ = worker.flush()
  }
}

// swiftlint:disable non_optional_string_data_conversion
private enum JSONDataConstants {
  static let arrayPrefix = "[".data(using: .utf8)!
  static let arraySuffix = "null]".data(using: .utf8)!
  static let arraySeparator = ",".data(using: .utf8)!
}

// swiftlint:enable non_optional_string_data_conversion
