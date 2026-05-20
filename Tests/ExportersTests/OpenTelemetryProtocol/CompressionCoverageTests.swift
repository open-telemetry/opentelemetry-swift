/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

#if canImport(Compression)
@testable import OpenTelemetryProtocolExporterHttp
import XCTest

final class CompressionCoverageTests: XCTestCase {
  func testDeflateProducesNonEmptyDataForShortInput() throws {
    let data = Data("hello otel".utf8)
    let deflated = try XCTUnwrap(data.deflate())
    XCTAssertFalse(deflated.isEmpty)
    // A 10-byte input should compress to something small but non-zero.
    XCTAssertGreaterThan(deflated.count, 0)
  }

  func testDeflateLargeInputExceedsBlockLimit() throws {
    // 128 KB exceeds the 64 KB block limit, exercising the chunked loop.
    let data = Data(repeating: 0x41, count: 128 * 1024)
    let deflated = try XCTUnwrap(data.deflate())
    // Highly compressible input should shrink a lot.
    XCTAssertLessThan(deflated.count, data.count)
  }

  func testGzipProducesMagicHeaderAndTrailer() throws {
    let payload = Data("gzipped otel payload".utf8)
    let gz = try XCTUnwrap(payload.gzip())
    // RFC 1952: first two bytes are 0x1f, 0x8b
    XCTAssertEqual(gz[0], 0x1f)
    XCTAssertEqual(gz[1], 0x8b)
    // deflate method = 0x08
    XCTAssertEqual(gz[2], 0x08)
    // Must include 10-byte header + at least 1 compressed byte + 8-byte trailer (crc + isize)
    XCTAssertGreaterThan(gz.count, 10 + 8)
  }

  func testGzipIncludesIsizeFromOriginalData() throws {
    let payload = Data(repeating: 0x42, count: 123)
    let gz = try XCTUnwrap(payload.gzip())
    // Last 4 bytes = isize (original length mod 2^32), little-endian.
    let n = gz.count
    let b0 = UInt32(gz[n - 4])
    let b1 = UInt32(gz[n - 3])
    let b2 = UInt32(gz[n - 2])
    let b3 = UInt32(gz[n - 1])
    let isize = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    XCTAssertEqual(isize, UInt32(payload.count))
  }

  func testCrc32EmptyChecksum() {
    var c = Crc32()
    c.advance(withChunk: Data())
    XCTAssertEqual(c.checksum, 0)
    XCTAssertEqual(c.description, "00000000")
  }

  func testCrc32StableValueForKnownInput() {
    // crc32("123456789") = 0xCBF43926 — canonical test vector.
    var c = Crc32()
    c.advance(withChunk: Data("123456789".utf8))
    XCTAssertEqual(c.checksum, 0xCBF43926)
    XCTAssertEqual(c.description, "cbf43926")
  }

  func testCrc32Chunked() {
    var whole = Crc32()
    whole.advance(withChunk: Data("123456789".utf8))

    var chunked = Crc32()
    chunked.advance(withChunk: Data("1234".utf8))
    chunked.advance(withChunk: Data("56789".utf8))

    XCTAssertEqual(whole.checksum, chunked.checksum)
  }
}
#endif
