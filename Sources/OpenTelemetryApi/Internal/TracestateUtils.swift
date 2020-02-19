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

struct TraceStateUtils {
    private static let keyMaxSize = 256
    private static let valueMaxSize = 256
    private static let maxKeyValuePairsCount = 32

    /// Extracts traceState pairs from the given string and appends it to provided traceState list
    /// - Parameters:
    ///   - traceStateString: String with comma separated traceState key value pairs.
    ///   - traceState: Array to set traceState pairs on.
    static func appendTraceState(traceStateString: String, traceState: inout [TraceState.Entry]) -> Bool {
        guard !traceState.isEmpty else { return false }

        var names = Set<String>()

        let traceStateString = traceStateString.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))

        // traceState: rojo=00-0af7651916cd43dd8448eb211c80319c-00f067aa0ba902b7-01,congo=BleGNlZWRzIHRohbCBwbGVhc3VyZS4
        let pair = traceStateString.components(separatedBy: ",")
        for entry in pair {
            if let entry = TraceStateUtils.parseKeyValue(pairString: entry), !names.contains(entry.key) {
                names.update(with: entry.key)
                traceState.append(entry)
            } else {
                return false
            }

            if traceState.count == maxKeyValuePairsCount {
                break
            }
        }
        return true
    }

    /// Returns TraceState description as a string with the values
    /// - Parameter traceState: the traceState to return description from
    static func getString(traceState: TraceState) -> String {
        let entries = traceState.entries
        var result = ""

        if entries.isEmpty {
            return result
        }

        for entry in traceState.entries.prefix(maxKeyValuePairsCount) {
            result += "\(entry.key)=\(entry.value),"
        }
        result.removeLast()
        return result
    }

    /// Key is opaque string up to 256 characters printable. It MUST begin with a lowercase letter, and
    /// can only contain lowercase letters a-z, digits 0-9, underscores _, dashes -, asterisks *, and
    /// forward slashes /.  For multi-tenant vendor scenarios, an at sign (@) can be used to prefix the
    /// vendor name.
    static func validateKey(key: String) -> Bool {
        let allowed = "abcdefghijklmnopqrstuvwxyz0123456789_-*/@"
        let characterSet = CharacterSet(charactersIn: allowed)

        if key.count > TraceStateUtils.keyMaxSize || key.isEmpty || key.unicodeScalars.first! > "z" {
            return false
        }
        guard key.rangeOfCharacter(from: characterSet.inverted) == nil else {
            return false
        }

        if key.firstIndex(of: "@") != key.lastIndex(of: "@") {
            return false
        }

        return true
    }

    /// Value is opaque string up to 256 characters printable ASCII RFC0020 characters (i.e., the range
    /// 0x20 to 0x7E) except comma , and =.
    static func validateValue(value: String) -> Bool {
        if value.count > TraceStateUtils.valueMaxSize || value.last == " " {
            return false
        }

        for scalar in value.unicodeScalars {
            if scalar.value < 0x20 || scalar.value > 0x7E || scalar == "," || scalar == "=" {
                return false
            }
        }

        return true
    }

    private static func parseKeyValue(pairString: String) -> TraceState.Entry? {
        let pair = pairString.components(separatedBy: "=")
        guard pair.count == 2 else { return nil }

        return TraceState.Entry(key: pair[0], value: pair[1])
    }
}
