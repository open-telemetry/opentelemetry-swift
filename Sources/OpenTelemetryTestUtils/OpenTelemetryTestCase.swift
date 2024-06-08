/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

@testable import OpenTelemetryApi
@testable import OpenTelemetrySdk
import XCTest
#if canImport(_Concurrency)
@testable import OpenTelemetryConcurrency
typealias ConcurrentOpenTelemetry = OpenTelemetryConcurrency.OpenTelemetry
#endif
typealias OpenTelemetry = OpenTelemetryApi.OpenTelemetry

open class OpenTelemetryTestCase: XCTestCase {
    public static func imperativeContextManagers() -> [ContextManager] {
        var managers = [ContextManager]()
#if canImport(os.activity)
        managers.append(ActivityContextManager.instance)
#endif
        return managers
    }

    public static func concurrencyContextManagers() -> [ContextManager] {
        var managers = [ContextManager]()
#if canImport(_Concurrency)
        managers.append(TaskLocalContextManager.instance)
#endif
        return managers
    }

    public static func allContextManagers() -> [ContextManager] {
        var managers = [ContextManager]()
#if canImport(os.activity)
        managers.append(ActivityContextManager.instance)
#endif
#if canImport(_Concurrency)
        managers.append(TaskLocalContextManager.instance)
#endif
        return managers
    }

#if canImport(os.activity)
    public static func activityContextManagers() -> [ContextManager] {
        var managers = [ContextManager]()
        managers.append(ActivityContextManager.instance)
        return managers
    }
#endif

    open var contextManagers: [any ContextManager] {
        OpenTelemetryTestCase.allContextManagers()
    }

    private var cachedManagers: [any ContextManager]?

    open override func perform(_ run: XCTestRun) {
        self.cachedManagers = self.contextManagers
        if self.cachedManagers!.isEmpty {
            print("Skipping Test Case '\(self.name)' due to no applicable context managers")
            return
        }

        super.perform(run)
    }

    open override func invokeTest() {
        for manager in self.cachedManagers! {
            OpenTelemetry.withContextManager(manager) {
                super.invokeTest()
            }
        }
    }

#if canImport(ObjectiveC)
    open override func record(_ issue: XCTIssue) {
        super.record(XCTIssue(
            type: issue.type,
            compactDescription: "\(issue.compactDescription) - with context manager \(OpenTelemetry.instance.contextProvider.contextManager)",
            detailedDescription: issue.detailedDescription,
            sourceCodeContext: issue.sourceCodeContext,
            associatedError: issue.associatedError,
            attachments: issue.attachments
        ))
    }
#else
    open override func recordFailure(withDescription description: String, inFile filePath: String, atLine lineNumber: Int, expected: Bool) {
        super.recordFailure(
            withDescription: "\(description) - with context manager \(OpenTelemetry.instance.contextProvider.contextManager)",
            inFile: filePath,
            atLine: lineNumber,
            expected: expected
        )
    }
#endif
}
