/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

protocol StoragePerformancePreset {
  /// Maximum size of a single file (in bytes).
  /// Each feature (logging, tracing, ...) serializes its objects data to that file for later export.
  /// If last written file is too big to append next data, new file is created.
  var maxFileSize: UInt64 { get }
  /// Maximum size of data directory (in bytes).
  /// Each feature uses separate directory.
  /// If this size is exceeded, the oldest files are deleted until this limit is met again.
  var maxDirectorySize: UInt64 { get }
  /// Maximum age qualifying given file for reuse (in seconds).
  /// If recently used file is younger than this, it is reused - otherwise: new file is created.
  var maxFileAgeForWrite: TimeInterval { get }
  /// Minimum age qualifying given file for export (in seconds).
  /// If the file is older than this, it is exported (and then deleted if export succeeded).
  /// It has an arbitrary offset  (~0.5s) over `maxFileAgeForWrite` to ensure that no export can start for the file being currently written.
  var minFileAgeForRead: TimeInterval { get }
  /// Maximum age qualifying given file for export (in seconds).
  /// Files older than this are considered obsolete and get deleted without exporting.
  var maxFileAgeForRead: TimeInterval { get }
  /// Maximum number of serialized objects written to a single file.
  /// If number of objects in recently used file reaches this limit, new file is created for new data.
  var maxObjectsInFile: Int { get }
  /// Maximum size of serialized object data (in bytes).
  /// If serialized object data exceeds this limit, it is skipped (not written to file and not exported).
  var maxObjectSize: UInt64 { get }
}

protocol ExportPerformancePreset {
  /// First export delay (in seconds).
  /// It is used as a base value until no more files eligible for export are found - then `defaultExportDelay` is used as a new base.
  var initialExportDelay: TimeInterval { get }
  /// Default exports interval (in seconds).
  /// At runtime, the export interval ranges from `minExportDelay` to `maxExportDelay` depending
  /// on delivery success or failure.
  var defaultExportDelay: TimeInterval { get }
  /// Minimum interval of data export (in seconds).
  var minExportDelay: TimeInterval { get }
  /// Maximum interval of data export (in seconds).
  var maxExportDelay: TimeInterval { get }
  /// If export succeeds or fails, current interval is changed by this rate. Should be less or equal `1.0`.
  /// E.g: if rate is `0.1` then `delay` can be increased or decreased by `delay * 0.1`.
  var exportDelayChangeRate: Double { get }
}

public struct PersistencePerformancePreset: Equatable, StoragePerformancePreset, ExportPerformancePreset {
  // MARK: - StoragePerformancePreset

  let maxFileSize: UInt64
  let maxDirectorySize: UInt64
  let maxFileAgeForWrite: TimeInterval
  let minFileAgeForRead: TimeInterval
  let maxFileAgeForRead: TimeInterval
  let maxObjectsInFile: Int
  let maxObjectSize: UInt64
  let synchronousWrite: Bool

  // MARK: - ExportPerformancePreset

  let initialExportDelay: TimeInterval
  let defaultExportDelay: TimeInterval
  let minExportDelay: TimeInterval
  let maxExportDelay: TimeInterval
  let exportDelayChangeRate: Double

  /// Public initializer to allow custom presets
  public init(
    maxFileSize: UInt64,
    maxDirectorySize: UInt64,
    maxFileAgeForWrite: TimeInterval,
    minFileAgeForRead: TimeInterval,
    maxFileAgeForRead: TimeInterval,
    maxObjectsInFile: Int,
    maxObjectSize: UInt64,
    synchronousWrite: Bool,
    initialExportDelay: TimeInterval,
    defaultExportDelay: TimeInterval,
    minExportDelay: TimeInterval,
    maxExportDelay: TimeInterval,
    exportDelayChangeRate: Double
  ) {
    self.maxFileSize = maxFileSize
    self.maxDirectorySize = maxDirectorySize
    self.maxFileAgeForWrite = maxFileAgeForWrite
    self.minFileAgeForRead = minFileAgeForRead
    self.maxFileAgeForRead = maxFileAgeForRead
    self.maxObjectsInFile = maxObjectsInFile
    self.maxObjectSize = maxObjectSize
    self.synchronousWrite = synchronousWrite
    self.initialExportDelay = initialExportDelay
    self.defaultExportDelay = defaultExportDelay
    self.minExportDelay = minExportDelay
    self.maxExportDelay = maxExportDelay
    self.exportDelayChangeRate = exportDelayChangeRate
  }

  // MARK: - Predefined presets

  /// Default performance preset.
  public static let `default` = lowRuntimeImpact

  /// Performance preset optimized for low runtime impact.
  /// Minimalizes number of data requests send to the server.
  public static let lowRuntimeImpact = PersistencePerformancePreset(maxFileSize: 4 * 1_024 * 1_024, // 4MB
                                                                    maxDirectorySize: 512 * 1_024 * 1_024, // 512 MB
                                                                    maxFileAgeForWrite: 4.75,
                                                                    minFileAgeForRead: 4.75 + 0.5, // `maxFileAgeForWrite` + 0.5s margin
                                                                    maxFileAgeForRead: 18 * 60 * 60, // 18h
                                                                    maxObjectsInFile: 500,
                                                                    maxObjectSize: 256 * 1_024, // 256KB
                                                                    synchronousWrite: false,
                                                                    initialExportDelay: 5, // postpone to not impact app launch time
                                                                    defaultExportDelay: 5,
                                                                    minExportDelay: 1,
                                                                    maxExportDelay: 20,
                                                                    exportDelayChangeRate: 0.1)

  /// Performance preset optimized for instant data delivery.
  /// Minimalizes the time between receiving data form the user and delivering it to the server.
  public static let instantDataDelivery = PersistencePerformancePreset(maxFileSize: `default`.maxFileSize,
                                                                       maxDirectorySize: `default`.maxDirectorySize,
                                                                       maxFileAgeForWrite: 2.75,
                                                                       minFileAgeForRead: 2.75 + 0.5, // `maxFileAgeForWrite` + 0.5s margin
                                                                       maxFileAgeForRead: `default`.maxFileAgeForRead,
                                                                       maxObjectsInFile: `default`.maxObjectsInFile,
                                                                       maxObjectSize: `default`.maxObjectSize,
                                                                       synchronousWrite: true,
                                                                       initialExportDelay: 0.5, // send quick to have a chance for export in short-lived app extensions
                                                                       defaultExportDelay: 3,
                                                                       minExportDelay: 1,
                                                                       maxExportDelay: 5,
                                                                       exportDelayChangeRate: 0.5 // reduce significantly for more exports in short-lived app extensions
  )
}
