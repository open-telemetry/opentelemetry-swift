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
import OpenTelemetryApi

/// LabelSet implementation.
class LabelSetSdk: LabelSet {
    internal var labelSetEncoded: String

    required init(labels: [String: String]) {
        labelSetEncoded = LabelSetSdk.getLabelSetEncoded(labels: labels)
        super.init(labels: labels)
    }

    private static func getLabelSetEncoded(labels: [String: String]) -> String {
        var output = ""
        var isFirstLabel = true

        labels.map { "\($0)=\($1)" }.sorted().forEach {
            if !isFirstLabel {
                output += ","
            }
            output += $0
            isFirstLabel = false
        }
        return output
    }
}
