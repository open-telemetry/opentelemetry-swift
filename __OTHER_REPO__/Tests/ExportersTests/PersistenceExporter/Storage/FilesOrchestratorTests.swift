/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import PersistenceExporter
import XCTest

class FilesOrchestratorTests: XCTestCase {
  private let performance: PersistencePerformancePreset = .default
  @UniqueTemporaryDirectory private var temporaryDirectory: Directory

  override func setUp() {
    super.setUp()
    temporaryDirectory.create()
  }

  override func tearDown() {
    temporaryDirectory.delete()
    super.tearDown()
  }

  /// Configures `FilesOrchestrator` under tests.
  private func configureOrchestrator(using dateProvider: DateProvider) -> FilesOrchestrator {
    return FilesOrchestrator(directory: temporaryDirectory,
                             performance: performance,
                             dateProvider: dateProvider)
  }

  // MARK: - Writable file tests

  func testGivenDefaultWriteConditions_whenUsedFirstTime_itCreatesNewWritableFile() throws {
    let dateProvider = RelativeDateProvider()
    let orchestrator = configureOrchestrator(using: dateProvider)
    _ = try orchestrator.getWritableFile(writeSize: 1)

    XCTAssertEqual(try temporaryDirectory.files().count, 1)
    XCTAssertNotNil(temporaryDirectory.file(named: dateProvider.currentDate().toFileName))
  }

  func testGivenDefaultWriteConditions_whenUsedNextTime_itReusesWritableFile() throws {
    let orchestrator = configureOrchestrator(using: RelativeDateProvider(advancingBySeconds: 1))
    let file1 = try orchestrator.getWritableFile(writeSize: 1)
    let file2 = try orchestrator.getWritableFile(writeSize: 1)

    XCTAssertEqual(try temporaryDirectory.files().count, 1)
    XCTAssertEqual(file1.name, file2.name)
  }

  func testGivenDefaultWriteConditions_whenFileCanNotBeUsedMoreTimes_itCreatesNewFile() throws {
    let orchestrator = configureOrchestrator(using: RelativeDateProvider(advancingBySeconds: 0.001))
    var previousFile: WritableFile = try orchestrator.getWritableFile(writeSize: 1) // first use
    var nextFile: WritableFile

    // use file maximum number of times
    for _ in (0 ..< performance.maxObjectsInFile).dropLast() { // skip first use
      nextFile = try orchestrator.getWritableFile(writeSize: 1)
      XCTAssertEqual(nextFile.name, previousFile.name) // assert it uses same file
      previousFile = nextFile
    }

    // next time it returns different file
    nextFile = try orchestrator.getWritableFile(writeSize: 1)
    XCTAssertNotEqual(nextFile.name, previousFile.name)
  }

  func testGivenDefaultWriteConditions_whenFileHasNoRoomForMore_itCreatesNewFile() throws {
    let orchestrator = configureOrchestrator(using: RelativeDateProvider(advancingBySeconds: 1))
    let chunkedData: [Data] = .mockChunksOf(totalSize: performance.maxFileSize,
                                            maxChunkSize: performance.maxObjectSize)

    let file1 = try orchestrator.getWritableFile(writeSize: performance.maxObjectSize)
    try chunkedData.forEach { chunk in try file1.append(data: chunk, synchronized: false) }
    let file2 = try orchestrator.getWritableFile(writeSize: 1)

    XCTAssertNotEqual(file1.name, file2.name)
  }

  func testGivenDefaultWriteConditions_fileIsNotRecentEnough_itCreatesNewFile() throws {
    let dateProvider = RelativeDateProvider()
    let orchestrator = configureOrchestrator(using: dateProvider)

    let file1 = try orchestrator.getWritableFile(writeSize: 1)
    dateProvider.advance(bySeconds: 1 + performance.maxFileAgeForWrite)
    let file2 = try orchestrator.getWritableFile(writeSize: 1)

    XCTAssertNotEqual(file1.name, file2.name)
  }

  func testWhenCurrentWritableFileIsDeleted_itCreatesNewOne() throws {
    let orchestrator = configureOrchestrator(using: RelativeDateProvider(advancingBySeconds: 1))

    let file1 = try orchestrator.getWritableFile(writeSize: 1)
    try temporaryDirectory.files().forEach { try $0.delete() }
    let file2 = try orchestrator.getWritableFile(writeSize: 1)

    XCTAssertNotEqual(file1.name, file2.name)
  }

  /// This test makes sure that if SDK is used by multiple processes simultaneously, each `FileOrchestrator` works on a separate writable file.
  /// It is important when SDK is used by iOS App and iOS App Extension at the same time.
  func testWhenRequestedFirstTime_eachOrchestratorInstanceCreatesNewWritableFile() throws {
    let orchestrator1 = configureOrchestrator(using: RelativeDateProvider())
    let orchestrator2 = configureOrchestrator(using: RelativeDateProvider(startingFrom: Date().secondsAgo(0.01)) // simulate time difference
    )

    _ = try orchestrator1.getWritableFile(writeSize: 1)
    XCTAssertEqual(try temporaryDirectory.files().count, 1)

    _ = try orchestrator2.getWritableFile(writeSize: 1)
    XCTAssertEqual(try temporaryDirectory.files().count, 2)
  }

  func testWhenFilesDirectorySizeIsBig_itKeepsItUnderLimit_byRemovingOldestFilesFirst() throws {
    let oneMB: UInt64 = 1024 * 1024

    let orchestrator = FilesOrchestrator(directory: temporaryDirectory,
                                         performance: StoragePerformanceMock(maxFileSize: oneMB, // 1MB
                                                                             maxDirectorySize: 3 * oneMB, // 3MB,
                                                                             maxFileAgeForWrite: .distantFuture,
                                                                             minFileAgeForRead: .mockAny(),
                                                                             maxFileAgeForRead: .mockAny(),
                                                                             maxObjectsInFile: 1, // create new file each time
                                                                             maxObjectSize: .max),
                                         dateProvider: RelativeDateProvider(advancingBySeconds: 1))

    // write 1MB to first file (1MB of directory size in total)
    let file1 = try orchestrator.getWritableFile(writeSize: oneMB)
    try file1.append(data: .mock(ofSize: oneMB), synchronized: false)

    // write 1MB to second file (2MB of directory size in total)
    let file2 = try orchestrator.getWritableFile(writeSize: oneMB)
    try file2.append(data: .mock(ofSize: oneMB), synchronized: true)

    // write 1MB to third file (3MB of directory size in total)
    let file3 = try orchestrator.getWritableFile(writeSize: oneMB + 1) // +1 byte to exceed the limit
    try file3.append(data: .mock(ofSize: oneMB + 1), synchronized: false)

    XCTAssertEqual(try temporaryDirectory.files().count, 3)

    // At this point, directory reached its maximum size.
    // Asking for the next file should purge the oldest one.
    let file4 = try orchestrator.getWritableFile(writeSize: oneMB)
    XCTAssertEqual(try temporaryDirectory.files().count, 3)
    XCTAssertNil(temporaryDirectory.file(named: file1.name))
    try file4.append(data: .mock(ofSize: oneMB + 1), synchronized: true)

    _ = try orchestrator.getWritableFile(writeSize: oneMB)
    XCTAssertEqual(try temporaryDirectory.files().count, 3)
    XCTAssertNil(temporaryDirectory.file(named: file2.name))
  }

  // MARK: - Readable file tests

  func testGivenDefaultReadConditions_whenThereAreNoFiles_itReturnsNil() throws {
    let dateProvider = RelativeDateProvider()
    let orchestrator = configureOrchestrator(using: dateProvider)
    dateProvider.advance(bySeconds: 1 + performance.minFileAgeForRead)
    XCTAssertNil(orchestrator.getReadableFile())
  }

  func testGivenDefaultReadConditions_whenFileIsOldEnough_itReturnsReadableFile() throws {
    let dateProvider = RelativeDateProvider()
    let orchestrator = configureOrchestrator(using: dateProvider)
    let file = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)

    dateProvider.advance(bySeconds: 1 + performance.minFileAgeForRead)
    XCTAssertEqual(orchestrator.getReadableFile()?.name, file.name)
  }

  func testGivenDefaultReadConditions_whenFileIsTooYoung_itReturnsNoFile() throws {
    let dateProvider = RelativeDateProvider()
    let orchestrator = configureOrchestrator(using: dateProvider)
    _ = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)

    dateProvider.advance(bySeconds: 0.5 * performance.minFileAgeForRead)
    XCTAssertNil(orchestrator.getReadableFile())
  }

  func testGivenDefaultReadConditions_whenThereAreSeveralFiles_itReturnsTheOldestOne() throws {
    let dateProvider = RelativeDateProvider(advancingBySeconds: 1)
    let orchestrator = configureOrchestrator(using: dateProvider)
    let fileNames = (0 ..< 4).map { _ in dateProvider.currentDate().toFileName }
    try fileNames.forEach { fileName in _ = try temporaryDirectory.createFile(named: fileName) }

    dateProvider.advance(bySeconds: 1 + performance.minFileAgeForRead)
    XCTAssertEqual(orchestrator.getReadableFile()?.name, fileNames[0])
    try temporaryDirectory.file(named: fileNames[0])?.delete()
    XCTAssertEqual(orchestrator.getReadableFile()?.name, fileNames[1])
    try temporaryDirectory.file(named: fileNames[1])?.delete()
    XCTAssertEqual(orchestrator.getReadableFile()?.name, fileNames[2])
    try temporaryDirectory.file(named: fileNames[2])?.delete()
    XCTAssertEqual(orchestrator.getReadableFile()?.name, fileNames[3])
    try temporaryDirectory.file(named: fileNames[3])?.delete()
    XCTAssertNil(orchestrator.getReadableFile())
  }

  func testGivenDefaultReadConditions_whenThereAreSeveralFiles_itExcludesGivenFileNames() throws {
    let dateProvider = RelativeDateProvider(advancingBySeconds: 1)
    let orchestrator = configureOrchestrator(using: dateProvider)
    let fileNames = (0 ..< 4).map { _ in dateProvider.currentDate().toFileName }
    try fileNames.forEach { fileName in _ = try temporaryDirectory.createFile(named: fileName) }

    dateProvider.advance(bySeconds: 1 + performance.minFileAgeForRead)

    XCTAssertEqual(orchestrator.getReadableFile(excludingFilesNamed: Set(fileNames[0 ... 2]))?.name,
                   fileNames[3])
  }

  func testGivenDefaultReadConditions_whenFileIsTooOld_itGetsDeleted() throws {
    let dateProvider = RelativeDateProvider()
    let orchestrator = configureOrchestrator(using: dateProvider)
    _ = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)

    dateProvider.advance(bySeconds: 2 * performance.maxFileAgeForRead)

    XCTAssertNil(orchestrator.getReadableFile())
    XCTAssertEqual(try temporaryDirectory.files().count, 0)
  }

  func testItDeletesReadableFile() throws {
    let dateProvider = RelativeDateProvider()
    let orchestrator = configureOrchestrator(using: dateProvider)
    _ = try temporaryDirectory.createFile(named: dateProvider.currentDate().toFileName)

    dateProvider.advance(bySeconds: 1 + performance.minFileAgeForRead)

    let readableFile = try orchestrator.getReadableFile().unwrapOrThrow()
    XCTAssertEqual(try temporaryDirectory.files().count, 1)
    orchestrator.delete(readableFile: readableFile)
    XCTAssertEqual(try temporaryDirectory.files().count, 0)
  }

  // MARK: - File names tests

  // swiftlint:disable number_separator
  func testItTurnsFileNameIntoFileCreationDate() {
    XCTAssertEqual(fileNameFrom(fileCreationDate: Date(timeIntervalSinceReferenceDate: 0)), "0")
    XCTAssertEqual(fileNameFrom(fileCreationDate: Date(timeIntervalSinceReferenceDate: 123456)), "123456000")
    XCTAssertEqual(fileNameFrom(fileCreationDate: Date(timeIntervalSinceReferenceDate: 123456.7)), "123456700")
    XCTAssertEqual(fileNameFrom(fileCreationDate: Date(timeIntervalSinceReferenceDate: 123456.78)), "123456780")
    XCTAssertEqual(fileNameFrom(fileCreationDate: Date(timeIntervalSinceReferenceDate: 123456.789)), "123456789")

    // microseconds rounding
    XCTAssertEqual(fileNameFrom(fileCreationDate: Date(timeIntervalSinceReferenceDate: 123456.1111)), "123456111")
    XCTAssertEqual(fileNameFrom(fileCreationDate: Date(timeIntervalSinceReferenceDate: 123456.1115)), "123456112")
    XCTAssertEqual(fileNameFrom(fileCreationDate: Date(timeIntervalSinceReferenceDate: 123456.1119)), "123456112")

    // overflows
    let maxDate = Date(timeIntervalSinceReferenceDate: TimeInterval.greatestFiniteMagnitude)
    let minDate = Date(timeIntervalSinceReferenceDate: -TimeInterval.greatestFiniteMagnitude)
    XCTAssertEqual(fileNameFrom(fileCreationDate: maxDate), "0")
    XCTAssertEqual(fileNameFrom(fileCreationDate: minDate), "0")
  }

  func testItTurnsFileCreationDateIntoFileName() {
    XCTAssertEqual(fileCreationDateFrom(fileName: "0"), Date(timeIntervalSinceReferenceDate: 0))
    XCTAssertEqual(fileCreationDateFrom(fileName: "123456000"), Date(timeIntervalSinceReferenceDate: 123456))
    XCTAssertEqual(fileCreationDateFrom(fileName: "123456700"), Date(timeIntervalSinceReferenceDate: 123456.7))
    XCTAssertEqual(fileCreationDateFrom(fileName: "123456780"), Date(timeIntervalSinceReferenceDate: 123456.78))
    XCTAssertEqual(fileCreationDateFrom(fileName: "123456789"), Date(timeIntervalSinceReferenceDate: 123456.789))

    // ignores invalid names
    let invalidFileName = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    XCTAssertEqual(fileCreationDateFrom(fileName: invalidFileName), Date(timeIntervalSinceReferenceDate: 0))
  }

  // swiftlint:enable number_separator
}
