/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest

typealias OpenTelemetry = OpenTelemetryApi.OpenTelemetry

/// A test case which runs its tests under (potentially) multiple context managers.
///
/// This is implemented by running the test method multiple times, once for each context manager the test case supports. If a test case doesn't have any supported managers on the current platform, a "skipping" message is printed and the test execution is stopped.
open class OpenTelemetryContextTestCase: XCTestCase {
  /// The context managers the test case supports. By default all available context managers will be used. Override this method to customize which managers are selected for this test case.
  open var contextManagers: [any ContextManager] {
    OpenTelemetryContextTestCase.allContextManagers()
  }

  private var cachedManagers: [any ContextManager]?

  override open func perform(_ run: XCTestRun) {
    cachedManagers = contextManagers
    if cachedManagers!.isEmpty {
      // Bail out before any other output is printed by the testing system to avoid confusion.
      print("Skipping Test Case '\(name)' due to no applicable context managers")
      return
    }

    super.perform(run)
  }

  override open func invokeTest() {
    for manager in cachedManagers! {
      // Install the desired context manager temporarily and re-run the test method.
      OpenTelemetry.withContextManager(manager) {
        super.invokeTest()
      }
    }
  }

  // Ensure we print out which context manager was in use when a failure is encountered.
  // Non-Apple platforms don't have access to `record(XCTIssue)` so we need to support both the new and old style method to avoid a deprecation warning on Apple platforms.
  #if canImport(ObjectiveC)
    override open func record(_ issue: XCTIssue) {
      super.record(XCTIssue(type: issue.type,
                            compactDescription: "\(issue.compactDescription) - with context manager \(OpenTelemetry.instance.contextProvider.contextManager)",
                            detailedDescription: issue.detailedDescription,
                            sourceCodeContext: issue.sourceCodeContext,
                            associatedError: issue.associatedError,
                            attachments: issue.attachments))
    }
  #else
    override open func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
      super.recordFailure(withDescription: "\(description) - with context manager \(OpenTelemetry.instance.contextProvider.contextManager)",
                          inFile: filePath,
                          atLine: lineNumber,
                          expected: expected)
    }
  #endif

  /// Context managers that can be used with the imperative style
  public static func imperativeContextManagers() -> [ContextManager] {
    var managers = [ContextManager]()
    #if canImport(os.activity)
      managers.append(ActivityContextManager.instance)
    #endif
    return managers
  }

  /// Context managers that can move context between related tasks when using structured concurrency
  public static func concurrencyContextManagers() -> [ContextManager] {
    var managers = [ContextManager]()
    #if canImport(_Concurrency)
      if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
        managers.append(TaskLocalContextManager.instance)
      }
    #endif
    return managers
  }

  /// All context managers supported on the current platform
  public static func allContextManagers() -> [ContextManager] {
    var managers = [ContextManager]()
    #if canImport(os.activity)
      managers.append(ActivityContextManager.instance)
    #endif
    #if canImport(_Concurrency)
      if #available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *) {
        managers.append(TaskLocalContextManager.instance)
      }
    #endif
    return managers
  }

  #if canImport(os.activity)
    /// Context managers that use the `os.activity` system for tracking context
    public static func activityContextManagers() -> [ContextManager] {
      var managers = [ContextManager]()
      managers.append(ActivityContextManager.instance)
      return managers
    }
  #endif
}
