// Copyright 2020, OpenTelemetry Authors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation

internal protocol StoragePerformancePreset {
    /// Maximum size of a single file (in bytes).
    /// Each feature (logging, tracing, ...) serializes its objects data to that file for later upload.
    /// If last written file is too big to append next data, new file is created.
    var maxFileSize: UInt64 { get }
    /// Maximum size of data directory (in bytes).
    /// Each feature uses separate directory.
    /// If this size is exceeded, the oldest files are deleted until this limit is met again.
    var maxDirectorySize: UInt64 { get }
    /// Maximum age qualifying given file for reuse (in seconds).
    /// If recently used file is younger than this, it is reused - otherwise: new file is created.
    var maxFileAgeForWrite: TimeInterval { get }
    /// Minimum age qualifying given file for upload (in seconds).
    /// If the file is older than this, it is uploaded (and then deleted if upload succeeded).
    /// It has an arbitrary offset  (~0.5s) over `maxFileAgeForWrite` to ensure that no upload can start for the file being currently written.
    var minFileAgeForRead: TimeInterval { get }
    /// Maximum age qualifying given file for upload (in seconds).
    /// Files older than this are considered obsolete and get deleted without uploading.
    var maxFileAgeForRead: TimeInterval { get }
    /// Maximum number of serialized objects written to a single file.
    /// If number of objects in recently used file reaches this limit, new file is created for new data.
    var maxObjectsInFile: Int { get }
    /// Maximum size of serialized object data (in bytes).
    /// If serialized object data exceeds this limit, it is skipped (not written to file and not uploaded).
    var maxObjectSize: UInt64 { get }
}

internal protocol UploadPerformancePreset {
    /// First upload delay (in seconds).
    /// It is used as a base value until no more files eligible for upload are found - then `defaultUploadDelay` is used as a new base.
    var initialUploadDelay: TimeInterval { get }
    /// Default uploads interval (in seconds).
    /// At runtime, the upload interval ranges from `minUploadDelay` to `maxUploadDelay` depending
    /// on delivery success or failure.
    var defaultUploadDelay: TimeInterval { get }
    /// Mininum  interval of data upload (in seconds).
    var minUploadDelay: TimeInterval { get }
    /// Maximum interval of data upload (in seconds).
    var maxUploadDelay: TimeInterval { get }
    /// If upload succeeds or fails, current interval is changed by this rate. Should be less or equal `1.0`.
    /// E.g: if rate is `0.1` then `delay` can be increased or decreased by `delay * 0.1`.
    var uploadDelayChangeRate: Double { get }
}

public struct PerformancePreset: Equatable, StoragePerformancePreset, UploadPerformancePreset {
    // MARK: - StoragePerformancePreset

    let maxFileSize: UInt64
    let maxDirectorySize: UInt64
    let maxFileAgeForWrite: TimeInterval
    let minFileAgeForRead: TimeInterval
    let maxFileAgeForRead: TimeInterval
    let maxObjectsInFile: Int
    let maxObjectSize: UInt64

    // MARK: - UploadPerformancePreset

    let initialUploadDelay: TimeInterval
    let defaultUploadDelay: TimeInterval
    let minUploadDelay: TimeInterval
    let maxUploadDelay: TimeInterval
    let uploadDelayChangeRate: Double

    // MARK: - Predefined presets

    /// Default performance preset.
    public static let `default` = lowRuntimeImpact

    /// Performance preset optimized for low runtime impact.
    /// Minimalizes number of data requests send to the server.
    public static let lowRuntimeImpact = PerformancePreset(
        // persistence
        maxFileSize: 4 * 1_024 * 1_024, // 4MB
        maxDirectorySize: 512 * 1_024 * 1_024, // 512 MB
        maxFileAgeForWrite: 4.75,
        minFileAgeForRead: 4.75 + 0.5, // `maxFileAgeForWrite` + 0.5s margin
        maxFileAgeForRead: 18 * 60 * 60, // 18h
        maxObjectsInFile: 500,
        maxObjectSize: 256 * 1_024, // 256KB

        // upload
        initialUploadDelay: 5, // postpone to not impact app launch time
        defaultUploadDelay: 5,
        minUploadDelay: 1,
        maxUploadDelay: 20,
        uploadDelayChangeRate: 0.1
    )

    /// Performance preset optimized for instant data delivery.
    /// Minimalizes the time between receiving data form the user and delivering it to the server.
    public static let instantDataDelivery = PerformancePreset(
        // persistence
        maxFileSize: `default`.maxFileSize,
        maxDirectorySize: `default`.maxDirectorySize,
        maxFileAgeForWrite: 2.75,
        minFileAgeForRead: 2.75 + 0.5, // `maxFileAgeForWrite` + 0.5s margin
        maxFileAgeForRead: `default`.maxFileAgeForRead,
        maxObjectsInFile: `default`.maxObjectsInFile,
        maxObjectSize: `default`.maxObjectSize,

        // upload
        initialUploadDelay: 0.5, // send quick to have a chance for upload in short-lived app extensions
        defaultUploadDelay: 3,
        minUploadDelay: 1,
        maxUploadDelay: 5,
        uploadDelayChangeRate: 0.5 // reduce significantly for more uploads in short-lived app extensions
    )
}
