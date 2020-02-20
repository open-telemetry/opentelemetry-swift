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

enum SpanContextParseError: Error {
    case UnsupportedVersion
}

/// Implementation of the binary propagation protocol on SpanContext.
public struct BinaryTraceContextFormat: BinaryFormattable {
    private static let versionId: UInt8 = 0
    private static let versionIdOffset: Int = 0
    private static let traceIdSize: Int = 16
    private static let spanIdSize: Int = 8
    private static let traceOptionsSize: Int = 1

    // The version_id/field_id size in bytes.
    private static let idSize: Int = 1
    private static let traceIdFieldId: UInt8 = 0
    private static let traceIdFieldIdOffset: Int = versionIdOffset + idSize
    private static let traceIdOffset: Int = traceIdFieldIdOffset + idSize
    private static let spanIdFieldId: UInt8 = 1
    private static let spanIdFieldIdOffset: Int = traceIdOffset + traceIdSize
    private static let spanIdOffset: Int = spanIdFieldIdOffset + idSize
    private static let traceOptionsFieldId: UInt8 = 2
    private static let traceOptionFieldIdOffset: Int = spanIdOffset + spanIdSize
    private static let traceOptionOffset: Int = traceOptionFieldIdOffset + idSize
    private static let requiredFormatLength = 3 * idSize + traceIdSize + spanIdSize
    private static let allFormatLength: Int = requiredFormatLength + idSize + traceOptionsSize

    public init() {}

    public func fromByteArray(bytes: [UInt8]) -> SpanContext? {
        if bytes.count == 0 || bytes[0] != BinaryTraceContextFormat.versionId ||
            bytes.count < BinaryTraceContextFormat.requiredFormatLength {
            return nil
        }

        var traceId = TraceId.invalid
        var spanId = SpanId.invalid
        var traceOptions = TraceFlags()
        var pos = 1

        if bytes.count >= pos + BinaryTraceContextFormat.idSize + BinaryTraceContextFormat.traceIdSize,
            bytes[pos] == BinaryTraceContextFormat.traceIdFieldId {
            traceId = TraceId(fromBytes: bytes[(pos + BinaryTraceContextFormat.idSize)...])
            pos += BinaryTraceContextFormat.idSize + BinaryTraceContextFormat.traceIdSize
        } else {
            return nil
        }

        if bytes.count >= pos + BinaryTraceContextFormat.idSize + BinaryTraceContextFormat.spanIdSize,
            bytes[pos] == BinaryTraceContextFormat.spanIdFieldId {
            spanId = SpanId(fromBytes: bytes[(pos + BinaryTraceContextFormat.idSize)...])
            pos += BinaryTraceContextFormat.idSize + BinaryTraceContextFormat.spanIdSize
        } else {
            return nil
        }

        if bytes.count >= pos + BinaryTraceContextFormat.idSize,
            bytes[pos] == BinaryTraceContextFormat.traceOptionsFieldId {
            if bytes.count < BinaryTraceContextFormat.allFormatLength {
                return nil
            }
            traceOptions = TraceFlags(fromByte: bytes[pos + BinaryTraceContextFormat.idSize])
        }

        return SpanContext.createFromRemoteParent(traceId: traceId,
                                                  spanId: spanId,
                                                  traceFlags: traceOptions,
                                                  traceState: TraceState())
    }

    public func toByteArray(spanContext: SpanContext) -> [UInt8] {
        var byteArray = [UInt8](repeating: 0, count: BinaryTraceContextFormat.allFormatLength)
        byteArray[BinaryTraceContextFormat.versionIdOffset] = BinaryTraceContextFormat.versionId
        byteArray[BinaryTraceContextFormat.traceIdFieldIdOffset] = BinaryTraceContextFormat.traceIdFieldId
        byteArray[BinaryTraceContextFormat.spanIdFieldIdOffset] = BinaryTraceContextFormat.spanIdFieldId
        byteArray[BinaryTraceContextFormat.traceOptionFieldIdOffset] = BinaryTraceContextFormat.traceOptionsFieldId
        byteArray[BinaryTraceContextFormat.traceOptionOffset] = spanContext.traceFlags.byte
        spanContext.traceId.copyBytesTo(dest: &byteArray, destOffset: BinaryTraceContextFormat.traceIdOffset)
        spanContext.spanId.copyBytesTo(dest: &byteArray, destOffset: BinaryTraceContextFormat.spanIdOffset)
        return byteArray
    }
}
