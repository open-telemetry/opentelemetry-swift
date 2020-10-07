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

/// Provides convenient interface for reading metadata and appending data to the file.
internal protocol WritableFile {
    /// Name of this file.
    var name: String { get }

    /// Current size of this file.
    func size() throws -> UInt64

    /// Synchronously appends given data at the end of this file.
    func append(data: Data) throws
}

/// Provides convenient interface for reading contents and metadata of the file.
internal protocol ReadableFile {
    /// Name of this file.
    var name: String { get }

    /// Reads the available data in this file.
    func read() throws -> Data

    /// Deletes this file.
    func delete() throws
}

/// An immutable `struct` designed to provide optimized and thread safe interface for file manipulation.
/// It doesn't own the file, which means the file presence is not guaranteed - the file can be deleted by OS at any time (e.g. due to memory pressure).
internal struct File: WritableFile, ReadableFile {
    let url: URL
    let name: String

    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
    }

    /// Appends given data at the end of this file.
    func append(data: Data) throws {
        let fileHandle = try FileHandle(forWritingTo: url)

        // NOTE: RUMM-669
        // https://github.com/DataDog/dd-sdk-ios/issues/214
        // https://en.wikipedia.org/wiki/Xcode#11.x_series
        // compiler version needs to have iOS 13.4+ as base SDK
        #if compiler(>=5.2)
        /**
          Even though the `fileHandle.seekToEnd()` should be available since iOS 13.0:
          ```
          @available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
          public func seekToEnd() throws -> UInt64
          ```
          it crashes on iOS Simulators prior to iOS 13.4:
          ```
          Symbol not found: _$sSo12NSFileHandleC10FoundationE9seekToEnds6UInt64VyKF
          ```
          This is fixed in iOS 14/Xcode 12
         */
        if #available(OSX 10.15, iOS 13.4, watchOS 6.0, tvOS 13.0, *) {
            defer { try? fileHandle.close() }
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
        } else {
            legacyAppend(data, to: fileHandle)
        }
        #else
        try legacyAppend(data, to: fileHandle)
        #endif
    }

    private func legacyAppend(_ data: Data, to fileHandle: FileHandle) {
        defer {
            fileHandle.closeFile()
        }
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
    }

    func read() throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: url)

        // NOTE: RUMM-669
        // https://github.com/DataDog/dd-sdk-ios/issues/214
        // https://en.wikipedia.org/wiki/Xcode#11.x_series
        // compiler version needs to have iOS 13.4+ as base SDK
        #if compiler(>=5.2)
        /**
          Even though the `fileHandle.seekToEnd()` should be available since iOS 13.0:
          ```
          @available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
          public func readToEnd() throws -> Data?
          ```
          it crashes on iOS Simulators prior to iOS 13.4:
          ```
          Symbol not found: _$sSo12NSFileHandleC10FoundationE9readToEndAC4DataVSgyKF
          ```
         This is fixed in iOS 14/Xcode 12
         */
        if #available(OSX 10.15, iOS 13.4, watchOS 6.0, tvOS 13.0, *) {
            defer { try? fileHandle.close() }
            return try fileHandle.readToEnd() ?? Data()
        } else {
            return legacyRead(from: fileHandle)
        }
        #else
        return legacyRead(from: fileHandle)
        #endif
    }

    private func legacyRead(from fileHandle: FileHandle) -> Data {
        let data = fileHandle.readDataToEndOfFile()
        fileHandle.closeFile()
        return data
    }

    func size() throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? UInt64 ?? 0
    }

    func delete() throws {
        try FileManager.default.removeItem(at: url)
    }
}
