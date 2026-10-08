/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
@testable import Crash

/// Raw KSCrash reports here are trimmed to the fields `CrashSummary` reads, using the shapes and
/// values of real reports captured from the demo app in the iOS simulator.
final class CrashSummaryTests: XCTestCase {
  private static let appPath = "/private/var/containers/Bundle/Application/UUID/HackerNewsDemo.app/HackerNewsDemo.debug.dylib"
  private static let swiftCorePath = "/usr/lib/swift/libswiftCore.dylib"
  private static let appBase: UInt64 = 4_322_148_352
  private static let swiftCoreBase: UInt64 = 6_846_615_552

  private static func image(_ path: String, base: UInt64, crashInfo: String? = nil) -> [String: Any] {
    var image: [String: Any] = ["cpu_subtype": 0, "cpu_type": 16_777_228, "image_addr": base, "image_size": 4096, "name": path]
    if let crashInfo {
      image["crash_info_message"] = crashInfo
    }
    return image
  }

  private static func frame(_ module: String, base: UInt64, offset: UInt64, symbol: String? = nil) -> [String: Any] {
    var frame: [String: Any] = ["object_name": module, "object_addr": base, "instruction_addr": base + offset]
    if let symbol {
      frame["symbol_name"] = symbol
    }
    return frame
  }

  /// The top frame in libswiftCore, then a frame in the app, as for a Swift runtime trap.
  private static var swiftTrapFrames: [[String: Any]] {
    [
      frame("libswiftCore.dylib", base: swiftCoreBase, offset: 1_053_200, symbol: "$ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF"),
      frame("HackerNewsDemo.debug.dylib", base: appBase, offset: 383_012)
    ]
  }

  private static var breakpointError: [String: Any] {
    [
      "type": "mach",
      "mach": ["exception": 6, "exception_name": "EXC_BREAKPOINT", "code": 1, "code_name": "KERN_INVALID_ADDRESS"],
      "signal": ["signal": 5, "name": "SIGTRAP", "code": 0, "code_name": "0"]
    ]
  }

  private func report(error: [String: Any],
                      frames: [[String: Any]] = swiftTrapFrames,
                      images: [[String: Any]]? = nil) throws -> Data {
    let defaultImages = [Self.image(Self.swiftCorePath, base: Self.swiftCoreBase), Self.image(Self.appPath, base: Self.appBase)]
    let raw: [String: Any] = [
      "report": ["id": "0CC96D1E-9950-44A3-9029-E893AF9723AB", "timestamp": 1_791_474_904_639_957, "type": "standard"],
      "binary_images": images ?? defaultImages,
      "crash": [
        "error": error,
        "threads": [
          ["index": 0, "crashed": false, "current_thread": false, "backtrace": ["contents": [Self.frame("libsystem_kernel.dylib", base: 4096, offset: 8)], "skipped": 0]],
          ["index": 14, "crashed": true, "current_thread": true, "backtrace": ["contents": frames, "skipped": 0]]
        ]
      ]
    ]
    return try JSONSerialization.data(withJSONObject: raw)
  }

  private func summary(_ data: Data, diagnosis: String? = nil) throws -> CrashSummary {
    try XCTUnwrap(CrashSummary(reportJSON: data, diagnosis: diagnosis), "the report did not decode")
  }

  // MARK: - Swift runtime traps

  func testSwiftTrapUsesTheRuntimeFatalErrorMessage() throws {
    let images = [
      Self.image(Self.swiftCorePath, base: Self.swiftCoreBase,
                 crashInfo: "HackerNewsDemo/IntegrationTestScenario.swift:128: Fatal error: integration test crash\n"),
      Self.image(Self.appPath, base: Self.appBase)
    ]
    let result = try summary(report(error: Self.breakpointError, images: images))
    XCTAssertEqual(result.type, "EXC_BREAKPOINT (SIGTRAP)")
    XCTAssertEqual(result.message, "HackerNewsDemo/IntegrationTestScenario.swift:128: Fatal error: integration test crash")
  }

  func testCrashInfoFromAnImageOnTheCrashedThreadWins() throws {
    let images = [
      Self.image("/usr/lib/dyld", base: 1, crashInfo: "dyld config: DYLD_LIBRARY_PATH=/usr/lib"),
      Self.image(Self.swiftCorePath, base: Self.swiftCoreBase, crashInfo: "Fatal error: Index out of range"),
      Self.image(Self.appPath, base: Self.appBase)
    ]
    XCTAssertEqual(try summary(report(error: Self.breakpointError, images: images)).message, "Fatal error: Index out of range")
  }

  func testCrashInfoFromAnotherImageIsUsedWhenNoCrashedImageHasOne() throws {
    let images = [
      Self.image(Self.swiftCorePath, base: Self.swiftCoreBase),
      Self.image(Self.appPath, base: Self.appBase),
      Self.image("/usr/lib/system/libsystem_c.dylib", base: 2, crashInfo: "abort() called")
    ]
    XCTAssertEqual(try summary(report(error: Self.breakpointError, images: images)).message, "abort() called")
  }

  func testBlankCrashInfoIsIgnored() throws {
    let images = [Self.image(Self.swiftCorePath, base: Self.swiftCoreBase, crashInfo: " \n"), Self.image(Self.appPath, base: Self.appBase)]
    XCTAssertEqual(try summary(report(error: Self.breakpointError, images: images)).message,
                   "EXC_BREAKPOINT (SIGTRAP) at HackerNewsDemo.debug.dylib + 383012")
  }

  // MARK: - Exceptions

  func testNSExceptionUsesItsNameAndTheRecordedReason() throws {
    // As KSCrash 2.6 records an uncaught NSException: the reason is on the error, not the exception.
    let error: [String: Any] = [
      "type": "nsexception",
      "nsexception": ["name": "NSRangeException"],
      "reason": "*** __boundsFail: index 10 beyond bounds [0 .. 2]",
      "signal": ["signal": 6, "name": "SIGABRT", "code": 0]
    ]
    let result = try summary(report(error: error), diagnosis: "Application threw exception NSRangeException")
    XCTAssertEqual(result.type, "NSRangeException")
    XCTAssertEqual(result.message, "NSRangeException: *** __boundsFail: index 10 beyond bounds [0 .. 2]")
  }

  func testNSExceptionReasonOnTheExceptionIsUsedToo() throws {
    let error: [String: Any] = ["type": "nsexception", "nsexception": ["name": "NSRangeException", "reason": "index 10 beyond bounds"]]
    XCTAssertEqual(try summary(report(error: error)).message, "NSRangeException: index 10 beyond bounds")
  }

  func testNSExceptionWithoutAReasonUsesItsName() throws {
    let error: [String: Any] = ["type": "nsexception", "nsexception": ["name": "MyAppException"]]
    let result = try summary(report(error: error))
    XCTAssertEqual(result.type, "MyAppException")
    XCTAssertEqual(result.message, "MyAppException")
  }

  func testCppExceptionUsesItsNameAndReason() throws {
    let error: [String: Any] = ["type": "cpp_exception", "cpp_exception": ["name": "std::runtime_error"], "reason": "connection lost"]
    let result = try summary(report(error: error))
    XCTAssertEqual(result.type, "std::runtime_error")
    XCTAssertEqual(result.message, "std::runtime_error: connection lost")
  }

  // MARK: - Mach exceptions and signals without a recorded message

  func testDiagnosisDescribesAMachException() throws {
    let error: [String: Any] = [
      "type": "mach",
      "mach": ["exception": 1, "exception_name": "EXC_BAD_ACCESS", "code": 1, "code_name": "KERN_INVALID_ADDRESS"],
      "signal": ["signal": 11, "name": "SIGSEGV", "code": 0],
      "address": 0
    ]
    let result = try summary(report(error: error), diagnosis: "Attempted to dereference null pointer.")
    XCTAssertEqual(result.type, "EXC_BAD_ACCESS (SIGSEGV)")
    XCTAssertEqual(result.message, "Attempted to dereference null pointer.")
  }

  func testDiagnosisDropsAnUnknownFunction() throws {
    // As KSCrash 2.6 diagnoses a stack overflow when it cannot name the function.
    let error: [String: Any] = ["type": "mach", "signal": ["signal": 11, "name": "SIGSEGV", "code": 0]]
    XCTAssertEqual(try summary(report(error: error), diagnosis: "Stack overflow in (null)").message, "Stack overflow")
    XCTAssertEqual(try summary(report(error: error), diagnosis: "Math error (usually caused from division by 0).\nOriginated at or in a subcall of (null)").message,
                   "Math error (usually caused from division by 0).")
  }

  func testDiagnosisKeepsAKnownFunction() throws {
    let error: [String: Any] = ["type": "mach", "signal": ["signal": 11, "name": "SIGSEGV", "code": 0]]
    XCTAssertEqual(try summary(report(error: error), diagnosis: "Stack overflow in recursiveFunction").message, "Stack overflow in recursiveFunction")
  }

  func testReasonIsUsedWhenThereIsNoBetterDescription() throws {
    let error: [String: Any] = ["type": "signal", "signal": ["signal": 6, "name": "SIGABRT", "code": 0], "reason": "assertion failed"]
    let result = try summary(report(error: error), diagnosis: "  ")
    XCTAssertEqual(result.type, "SIGABRT")
    XCTAssertEqual(result.message, "assertion failed")
  }

  func testFallbackNamesTheFirstAppFrameRatherThanTheSystemTopFrame() throws {
    let error: [String: Any] = ["type": "signal", "signal": ["signal": 6, "name": "SIGABRT", "code": 0]]
    XCTAssertEqual(try summary(report(error: error)).message, "SIGABRT at HackerNewsDemo.debug.dylib + 383012")
  }

  func testFallbackUsesTheTopFrameWhenNoAppFrameIsOnTheStack() throws {
    let frames = [Self.frame("libswiftCore.dylib", base: Self.swiftCoreBase, offset: 1_053_200)]
    XCTAssertEqual(try summary(report(error: Self.breakpointError, frames: frames)).message,
                   "EXC_BREAKPOINT (SIGTRAP) at libswiftCore.dylib + 1053200")
  }

  func testFallbackOffsetIsFromTheImageStartWhetherOrNotTheFrameWasSymbolicated() throws {
    let symbolicated = [Self.frame(Self.appPath.components(separatedBy: "/").last!, base: Self.appBase, offset: 383_012, symbol: "$sIegh_IeyBh_TR")]
    let plain = [Self.frame(Self.appPath.components(separatedBy: "/").last!, base: Self.appBase, offset: 383_012)]
    XCTAssertEqual(try summary(report(error: Self.breakpointError, frames: symbolicated)).message,
                   try summary(report(error: Self.breakpointError, frames: plain)).message)
  }

  func testFallbackWithoutFramesSaysTheLocationIsUnknown() throws {
    XCTAssertEqual(try summary(report(error: Self.breakpointError, frames: [])).message,
                   "EXC_BREAKPOINT (SIGTRAP) at unknown location")
  }

  func testCrashedThreadNumberIsNotPartOfTheMessage() throws {
    let message = try summary(report(error: Self.breakpointError)).message
    XCTAssertFalse(message.contains("14"), "the crashed thread's number must not appear: \(message)")
  }

  // MARK: - Other KSCrash report types

  func testTerminationUsesItsTypeAndTheDiagnosis() throws {
    let error: [String: Any] = ["type": "termination", "signal": ["signal": 9, "name": "SIGKILL", "code": 0]]
    let result = try summary(report(error: error, frames: []), diagnosis: "The app was terminated for an unknown reason.")
    XCTAssertEqual(result.type, "termination")
    XCTAssertEqual(result.message, "The app was terminated for an unknown reason.")
  }

  func testUnknownKSCrashTypeIsPassedThrough() throws {
    let result = try summary(report(error: ["type": "something_new"], frames: []))
    XCTAssertEqual(result.type, "something_new")
    XCTAssertEqual(result.message, "something_new at unknown location")
  }

  // MARK: - Decoding

  func testUndecodableReportYieldsNil() throws {
    XCTAssertNil(CrashSummary(reportJSON: Data("{\"crash\": {}}".utf8), diagnosis: nil))
    XCTAssertNil(CrashSummary(reportJSON: Data("not json".utf8), diagnosis: nil))
  }
}
