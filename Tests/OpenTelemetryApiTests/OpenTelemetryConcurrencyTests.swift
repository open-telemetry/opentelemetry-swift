/*
 * Copyright The OpenTelemetry Authors
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import XCTest
@testable import OpenTelemetryApi

/// Tests that exercise concurrent access patterns on the OpenTelemetry singleton
/// to verify thread safety of registration and access operations.
final class OpenTelemetryConcurrencyTests: XCTestCase {

  override func tearDown() {
    // Reset to defaults after each test
    OpenTelemetry.registerTracerProvider(tracerProvider: DefaultTracerProvider.instance)
    OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
    OpenTelemetry.registerBaggageManager(baggageManager: DefaultBaggageManager.instance)
    OpenTelemetry.registerMeterProvider(meterProvider: DefaultMeterProvider.instance)
    super.tearDown()
  }

  // MARK: - Concurrent reads

  func testConcurrentReadsOfTracerProvider() {
    let iterations = 1000
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.reads", attributes: .concurrent)

    for _ in 0..<iterations {
      group.enter()
      queue.async {
        _ = OpenTelemetry.instance.tracerProvider
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent reads should complete without deadlock")
  }

  func testConcurrentReadsOfAllProperties() {
    let iterations = 500
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.all.reads", attributes: .concurrent)

    for i in 0..<iterations {
      group.enter()
      queue.async {
        switch i % 6 {
        case 0: _ = OpenTelemetry.instance.tracerProvider
        case 1: _ = OpenTelemetry.instance.loggerProvider
        case 2: _ = OpenTelemetry.instance.meterProvider
        case 3: _ = OpenTelemetry.instance.baggageManager
        case 4: _ = OpenTelemetry.instance.propagators
        case 5: _ = OpenTelemetry.instance.contextProvider
        default: break
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent reads of all properties should complete")
  }

  // MARK: - Concurrent writes (register calls)

  func testConcurrentRegisterTracerProvider() {
    let iterations = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.register.tracer", attributes: .concurrent)

    for _ in 0..<iterations {
      group.enter()
      queue.async {
        OpenTelemetry.registerTracerProvider(tracerProvider: DefaultTracerProvider.instance)
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent registerTracerProvider should not crash")
  }

  func testConcurrentRegisterLoggerProvider() {
    let iterations = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.register.logger", attributes: .concurrent)

    for _ in 0..<iterations {
      group.enter()
      queue.async {
        OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent registerLoggerProvider should not crash")
  }

  func testConcurrentRegisterMeterProvider() {
    let iterations = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.register.meter", attributes: .concurrent)

    for _ in 0..<iterations {
      group.enter()
      queue.async {
        OpenTelemetry.registerMeterProvider(meterProvider: DefaultMeterProvider.instance)
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent registerMeterProvider should not crash")
  }

  func testConcurrentRegisterMultipleProviders() {
    let iterations = 100
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.register.multi", attributes: .concurrent)

    for i in 0..<iterations {
      group.enter()
      queue.async {
        switch i % 4 {
        case 0:
          OpenTelemetry.registerTracerProvider(tracerProvider: DefaultTracerProvider.instance)
        case 1:
          OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
        case 2:
          OpenTelemetry.registerMeterProvider(meterProvider: DefaultMeterProvider.instance)
        case 3:
          OpenTelemetry.registerBaggageManager(baggageManager: DefaultBaggageManager.instance)
        default: break
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent registration of multiple providers should not crash")
  }

  // MARK: - Concurrent read during write (the critical race)

  func testConcurrentReadDuringWrite() {
    let iterations = 500
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.read.write", attributes: .concurrent)

    for i in 0..<iterations {
      group.enter()
      queue.async {
        if i % 2 == 0 {
          // Reader
          _ = OpenTelemetry.instance.tracerProvider
        } else {
          // Writer
          OpenTelemetry.registerTracerProvider(tracerProvider: DefaultTracerProvider.instance)
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent read during write should not crash")
  }

  func testConcurrentReadDuringWriteAllProviders() {
    let iterations = 600
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.read.write.all", attributes: .concurrent)

    for i in 0..<iterations {
      group.enter()
      queue.async {
        switch i % 6 {
        case 0:
          _ = OpenTelemetry.instance.tracerProvider
        case 1:
          _ = OpenTelemetry.instance.loggerProvider
        case 2:
          _ = OpenTelemetry.instance.meterProvider
        case 3:
          OpenTelemetry.registerTracerProvider(tracerProvider: DefaultTracerProvider.instance)
        case 4:
          OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
        case 5:
          OpenTelemetry.registerMeterProvider(meterProvider: DefaultMeterProvider.instance)
        default: break
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Mixed concurrent reads and writes should not crash")
  }

  // MARK: - Propagators concurrent access

  func testConcurrentPropagatorAccess() {
    let iterations = 200
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.propagators", attributes: .concurrent)

    for i in 0..<iterations {
      group.enter()
      queue.async {
        if i % 3 == 0 {
          OpenTelemetry.registerPropagators(
            textPropagators: [W3CTraceContextPropagator()],
            baggagePropagator: W3CBaggagePropagator()
          )
        } else {
          _ = OpenTelemetry.instance.propagators
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent propagator access should not crash")
  }

  // MARK: - Context provider concurrent access

  func testConcurrentContextProviderAccess() {
    let iterations = 200
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.concurrent.context", attributes: .concurrent)

    for i in 0..<iterations {
      group.enter()
      queue.async {
        if i % 4 == 0 {
          // Read context provider
          _ = OpenTelemetry.instance.contextProvider
        } else {
          // Read active span (goes through context provider)
          _ = OpenTelemetry.instance.contextProvider.activeSpan
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "Concurrent context provider access should not crash")
  }

  // MARK: - Stress test: high-contention scenario

  func testHighContentionStress() {
    let writerCount = 4
    let readerCount = 8
    let iterationsPerThread = 200
    let group = DispatchGroup()
    let queue = DispatchQueue(label: "test.stress", attributes: .concurrent)

    // Spawn writer threads
    for _ in 0..<writerCount {
      group.enter()
      queue.async {
        for _ in 0..<iterationsPerThread {
          OpenTelemetry.registerTracerProvider(tracerProvider: DefaultTracerProvider.instance)
          OpenTelemetry.registerLoggerProvider(loggerProvider: DefaultLoggerProvider.instance)
        }
        group.leave()
      }
    }

    // Spawn reader threads
    for _ in 0..<readerCount {
      group.enter()
      queue.async {
        for _ in 0..<iterationsPerThread {
          _ = OpenTelemetry.instance.tracerProvider
          _ = OpenTelemetry.instance.loggerProvider
          _ = OpenTelemetry.instance.meterProvider
          _ = OpenTelemetry.instance.contextProvider
        }
        group.leave()
      }
    }

    waitForConcurrentWork(group, "High contention stress test should complete without crash")
  }
}
