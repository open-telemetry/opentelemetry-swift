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

@testable import DatadogExporter
import Foundation

/*
 Set of Datadog domain extensions over standard types for writting more readable tests.
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
