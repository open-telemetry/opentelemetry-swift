/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import XCTest

final class FileCoverageTests: XCTestCase {
  @UniqueTemporaryDirectory private var temporaryDirectory: Directory

  override func setUp() {
    super.setUp()
    temporaryDirectory.create()
  }

  override func tearDown() {
    temporaryDirectory.delete()
    super.tearDown()
  }

  func testAppendAndReadRoundTrip() throws {
    let file = try temporaryDirectory.createFile(named: "roundtrip")
    try file.append(data: Data("hello ".utf8), synchronized: false)
    try file.append(data: Data("world".utf8), synchronized: false)
    XCTAssertEqual(try file.read(), Data("hello world".utf8))
  }

  func testAppendSynchronizedWritesToDisk() throws {
    let file = try temporaryDirectory.createFile(named: "sync")
    try file.append(data: Data("sync-data".utf8), synchronized: true)
    XCTAssertEqual(try file.read(), Data("sync-data".utf8))
  }

  func testSizeReflectsAccumulatedWrites() throws {
    let file = try temporaryDirectory.createFile(named: "size")
    try file.append(data: Data(repeating: 0x41, count: 100), synchronized: false)
    XCTAssertEqual(try file.size(), 100)
    try file.append(data: Data(repeating: 0x42, count: 50), synchronized: false)
    XCTAssertEqual(try file.size(), 150)
  }

  func testDeleteRemovesFile() throws {
    let file = try temporaryDirectory.createFile(named: "delete-me")
    try file.append(data: Data("x".utf8), synchronized: false)
    try file.delete()
    XCTAssertThrowsError(try file.read())
  }

  func testReadEmptyFileYieldsEmptyData() throws {
    let file = try temporaryDirectory.createFile(named: "empty")
    XCTAssertEqual(try file.read(), Data())
  }

  func testNamePropertyMatchesLastPathComponent() throws {
    let file = try temporaryDirectory.createFile(named: "named-file")
    XCTAssertEqual(file.name, "named-file")
  }
}
