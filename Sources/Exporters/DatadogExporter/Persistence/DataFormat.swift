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

/// Describes the format of writing and reading data from files.
internal struct DataFormat {
    /// Prefixes the batch payload read from file.
    let prefixData: Data
    /// Suffixes the batch payload read from file.
    let suffixData: Data
    /// Separates entities written to file.
    let separatorData: Data

    // MARK: - Initialization

    init(
        prefix: String,
        suffix: String,
        separator: String
    ) {
        self.prefixData = prefix.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
        self.suffixData = suffix.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
        self.separatorData = separator.data(using: .utf8)! // swiftlint:disable:this force_unwrapping
    }
}
