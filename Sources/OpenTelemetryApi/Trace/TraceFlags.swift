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

/// A struct that represents global trace options. These options are propagated to all child spans.
/// These determine features such as whether a Span should be traced. It is
/// implemented as a bitmask.
public struct TraceFlags: Equatable, CustomStringConvertible {
    /// Default options. Nothing set.
    private static let defaultOptions: UInt8 = 0
    /// Bit to represent whether trace is sampled or not.
    private static let isSampled: UInt8 = 0x1

    /// The size in bytes of the TraceFlags.
    static let size = 1

    private static let base16Size = 2 * size

    /// The set of enabled features is determined by all the enabled bits.
    private var options: UInt8 = 0

    /// Returns the one byte representation of the TraceFlags.
    var byte: UInt8 {
        return options
    }

    /// Returns the lowercase base16 encoding of this TraceFlags
    public var hexString: String {
        return String(format: "%02x", options)
    }

    /// Creates the default TraceFlags
    public init() {
    }

    /// Creates a new TraceFlags with the given options.
    /// - Parameter fromByte: the byte representation of the TraceFlags.
    public init(fromByte src: UInt8) {
        options = src
    }

    /// Returns a TraceOption built from a lowercase base16 representation.
    /// - Parameters:
    ///   - hex: the lowercase base16 representation
    ///   - offset: the offset in the buffer where the representation of the TraceFlags begins
    public init(fromHexString hex: String, withOffset offset: Int = 0) {
        let firstIndex = hex.index(hex.startIndex, offsetBy: offset)
        let secondIndex = hex.index(firstIndex, offsetBy: 2)
        guard hex.count >= 2 + offset,
            let byte = UInt8(hex[firstIndex ..< secondIndex], radix: 16) else {
            self.init()
            return
        }
        self.init(fromByte: byte)
    }

    /// A boolean indicating whether this Span  is part of a sampled trace and data
    /// should be exported to a persistent store.
    public var sampled: Bool {
        return options & TraceFlags.isSampled != 0
    }

    /// Sets the sampling bit in the options.
    /// - Parameter isSampled: the sampling bit
    public mutating func setIsSampled(_ isSampled: Bool) {
        if isSampled {
            options = (options | TraceFlags.isSampled)
        } else {
            options = (options & ~TraceFlags.isSampled)
        }
    }

    /// Sets the sampling bit in the options.
    /// - Parameter isSampled: the sampling bit
    public func settingIsSampled(_ isSampled: Bool) -> TraceFlags {
        var optionsCopy: UInt8
        if isSampled {
            optionsCopy = (options | TraceFlags.isSampled)
        } else {
            optionsCopy = (options & ~TraceFlags.isSampled)
        }
        return TraceFlags(fromByte: optionsCopy)
    }

    public var description: String {
        "TraceFlags{sampled=\(sampled)}"
    }
}
