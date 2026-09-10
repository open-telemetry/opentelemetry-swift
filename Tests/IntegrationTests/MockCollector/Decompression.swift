/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

enum Decompression {
  enum Error: Swift.Error {
    case unsupportedEncoding(String)
    case malformedGzip
    case inflateFailed
  }

  static func decode(_ body: Data, contentEncoding: String?) throws -> Data {
    switch contentEncoding?.lowercased() {
    case nil, "identity":
      return body
    case "gzip":
      return try gunzip(body)
    case "deflate":
      return try inflate(body)
    case let .some(other):
      throw Error.unsupportedEncoding(other)
    }
  }

  // The OTLP exporters emit a fixed 10 byte gzip header with no optional
  // fields, followed by a raw deflate stream and an 8 byte CRC/size trailer.
  private static func gunzip(_ data: Data) throws -> Data {
    let headerLength = 10
    let trailerLength = 8
    guard data.count > headerLength + trailerLength,
          data[data.startIndex] == 0x1f,
          data[data.startIndex + 1] == 0x8b,
          data[data.startIndex + 2] == 0x08 else {
      throw Error.malformedGzip
    }
    let flags = data[data.startIndex + 3]
    guard flags == 0 else { throw Error.malformedGzip }
    let deflated = data.subdata(in: (data.startIndex + headerLength) ..< (data.endIndex - trailerLength))
    return try inflate(deflated)
  }

  private static func inflate(_ data: Data) throws -> Data {
    do {
      return try (data as NSData).decompressed(using: .zlib) as Data
    } catch {
      throw Error.inflateFailed
    }
  }
}
